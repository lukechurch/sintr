// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';

import 'package:gcloud/storage.dart' as storage;
import 'package:gcloud/db.dart' as db;
import 'package:gcloud/service_scope.dart' as ss;
import 'package:gcloud/src/datastore_impl.dart' as datastore_impl;
import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/auth.dart';
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/gae_utils.dart' as gae_utils;
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_common/source_utils.dart';
import 'package:sintr_common/tasks.dart' as tasks;

String workerFolder;
const START_NAME = "worker_isolate.dart";

// Worker properties.
SendPort sendPort;
ReceivePort receivePort;
Isolate isolate;

StreamController resultsController;
Stream resultsStream;
String shaCodeRunningInIsolate;

// var dbService;

main(List<String> args) async {
  if (args.length != 3) {
    print ("Worker node for sintr");
    print("Usage: dart startup.dart project_name job_name worker_folder");
    print(args);
    io.exit(1);
  }

  log.setupLogging();
  log.debug("Startup args: $args");

  String projectName = args[0];
  String jobName = args[1];
  String _workerFolder = args[2];
  await start(projectName, jobName, _workerFolder);
}

start(String projectName, String jobName, String _workerFolder) async {
  workerFolder = _workerFolder;
  config.configuration = new config.Configuration(projectName,
      cryptoTokensLocation: "${config.userHomePath}/Communications/CryptoTokens");

  var client = await auth.getAuthedClient();
  var dbService =
      new db.DatastoreDB(new datastore_impl.DatastoreImpl(client, "s~$projectName"));
      var sourceStorage = new storage.Storage(client, projectName);

      ss.fork(() async {
        storage.registerStorageService(sourceStorage);
        db.registerDbService(dbService);

        tasks.TaskController taskController =
            new tasks.TaskController(jobName);
            log.trace("Task loop starting");

            while (true) {
               var task = await taskController.getNextReadyTask();

               if (task == null) {
                 log.info("Got null next ready task, sleeping");
                 await new Future.delayed(new Duration(seconds: 5));
                 continue;
               }

               Stopwatch sw = new Stopwatch()..start();
               await _handleTask(task);
               log.perf("Task $task completed", sw.elapsedMilliseconds);
            }

      });
}

_handleTask(tasks.Task task) async {
  log.trace("Starting task $task");
  String lastSeenMd5 = null;
  String cachedSource = null;

  Stopwatch sw = new Stopwatch()..start();
  try {

    task.setState(tasks.LifecycleState.STARTED);


    log.trace("About to get source");
    String sourceJSON;

    gae_utils.CloudStorageLocation sourceLocation = await task.sourceLocation;
    if (lastSeenMd5 != null && sourceLocation.md5 == lastSeenMd5) {
      log.trace("Source cache hit: $lastSeenMd5");
      if (cachedSource == null) {
        throw "Invariant check failed: Cached key matched but source was null";
      }

      sourceJSON = cachedSource;
    } else {
      sourceJSON = await
        gae_utils.CloudStorage.getFileContentsByLocation(sourceLocation)
            .transform(UTF8.decoder).join();
        lastSeenMd5 = sourceLocation.md5;
        cachedSource = sourceJSON;
        log.trace("Cache miss: Source acquired $lastSeenMd5");
    }

    var sourceMap = JSON.decode(sourceJSON);
    _ensureSourceIsInstalled(sourceMap);
    log.trace("Source installed");

    gae_utils.CloudStorageLocation inputLocation = await task.inputSource;
    String locationJSON =
      JSON.encode([inputLocation.bucketName, inputLocation.objectPath]);

    int elasped = sw.elapsedMilliseconds;
    log.perf("Source acquired", elasped);

    log.trace("Sending: $locationJSON");
    sendPort.send(locationJSON);

    // TOOD: Replace this with a streaming write to cloud storage
    String response = await resultsStream.first;
    log.debug("Response: $response");

    elasped = sw.elapsedMilliseconds;
    log.perf("Response recieved", elasped);

    var resultsLocation = await task.resultLocation;

    await gae_utils.CloudStorage.writeFileBytes(
      resultsLocation.bucketName, resultsLocation.objectPath,
      UTF8.encode(response));

    // await gae_utils.CloudStorage.writeFileContents(
    //   resultsLocation.bucketName, objectPathForResult).addStream(
    //     new Stream.fromIterable(UTF8.encode(response)));

    elasped = sw.elapsedMilliseconds;
    log.perf("Result uploaded", elasped);

    await task.setState(tasks.LifecycleState.DONE);

    // TODO: Move this into the task API rather than needing to edit
    // the backing object
    await task.recordProgress();

    elasped = sw.elapsedMilliseconds;
    log.perf("Task $task Done", elasped);

  } catch (e, st) {
    log.info("Worker threw an exception: $e\n$st");

    // TODO: Model with failure count
    task.setState(tasks.LifecycleState.DEAD);
  }
}

_ensureSourceIsInstalled(Map<String, String> codeMap) {
  String sha = computeCodeSha(codeMap);

  if (sha == shaCodeRunningInIsolate) {
    log.debug("Code already installed: $sha");
    // The right code is already installed and hot
    return;
  }

  // Shutdown the existing isolate
  log.debug("Killing existing isolate");
  if (isolate != null) {
    isolate.kill();
    isolate = null;
  }

  // Write the code to the folder
  // TODO: This needs corresponding teardown, otherwise we have to wipe the VMs
  // between each execution
  for (String sourceName in codeMap.keys) {
    // Ensure that the folder structures are in place
    new io.File("$workerFolder$sourceName").createSync(recursive: true);
    new io.File("$workerFolder$sourceName").writeAsStringSync(codeMap[sourceName]);
  }
  _setupIsolate("$workerFolder$START_NAME");

  log.debug("Isolate started with sha: $sha");
  shaCodeRunningInIsolate = sha;
}

_setupIsolate(String startPath) async {
  log.debug("_setupIsolate: $startPath");
  sendPort = null;
  receivePort = new ReceivePort();
  resultsController = new StreamController();
  resultsStream = resultsController.stream.asBroadcastStream();

  log.debug("About to bind to recieve port");
  receivePort.listen((msg) {
    if (sendPort == null) {
      log.debug("send port recieved");
      sendPort = msg;
    } else {
      resultsController.add(msg);
    }
  });

  isolate =
      await Isolate.spawnUri(Uri.parse(startPath), [], receivePort.sendPort);
  isolate.setErrorsFatal(false);
  log.info("Worker isolate spawned");
}
