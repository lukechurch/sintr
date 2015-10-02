// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';

import 'package:gcloud/db.dart' as db;
import 'package:gcloud/service_scope.dart' as ss;
import 'package:gcloud/src/datastore_impl.dart' as datastore_impl;
import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/auth.dart';
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/gae_utils.dart' as gae_utils;
import 'package:sintr_common/logging_utils.dart' as logging_utils;
import 'package:sintr_common/source_utils.dart';
import 'package:sintr_common/tasks.dart' as tasks;

// import 'package:memcache/memcache.dart' as mc;



final _log = new logging_utils.Logger("worker");
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

  logging_utils.setupLogging();
  _log.finest(args);

  String projectName = args[0];
  String jobName = args[1];
  String _workerFolder = args[2];
  await start(projectName, jobName, _workerFolder);
}

start(String projectName, String jobName, String _workerFolder) async {
  workerFolder = _workerFolder;
  config.configuration = new config.Configuration(projectName,
      cryptoTokensLocation: "crypto");

  var client = await auth.getAuthedClient();
  var dbService =
      new db.DatastoreDB(new datastore_impl.DatastoreImpl(client, "s~$projectName"));
      ss.fork(() async {

        db.registerDbService(dbService);

        tasks.TaskController taskController =
            new tasks.TaskController(jobName);

            while (true) {
               var task = await taskController.getNextReadyTask();

               if (task == null) {
                 _log.finer("Got null next ready task, sleeping");
                 await new Future.delayed(new Duration(seconds: 5));
                 continue;
               }

               Stopwatch sw = new Stopwatch()..start();
               await _handleTask(task);
               _log.fine(
                 "PERF: Task $task completed in ${sw.elapsedMilliseconds}");
            }

      });
}

_handleTask(tasks.Task task) async {
  _log.finer("Starting task $task");

  Stopwatch sw = new Stopwatch()..start();
  try {

    task.setState(tasks.LifecycleState.STARTED);

    // TODO: Cache source
    String sourceJSON = await
      gae_utils.CloudStorage.getFileContentsByLocation(await task.sourceLocation)
      .transform(UTF8.decoder).join();

    var sourceMap = JSON.decode(sourceJSON);
    _ensureSourceIsInstalled(sourceMap);

    gae_utils.CloudStorageLocation inputLocation = await task.inputSource;
    String locationJSON =
      JSON.encode([inputLocation.bucketName, inputLocation.objectPath]);

    int elasped = sw.elapsedMilliseconds;
    _log.finer("PERF: Source acquired: ${elasped}");

    _log.fine("Sending: $locationJSON");
    sendPort.send(locationJSON);

    // TOOD: Replace this with a streaming write to cloud storage
    String response = await resultsStream.first;
    _log.fine("Response: $response");

    elasped = sw.elapsedMilliseconds;
    _log.finer("PERF: Response recieved ${elasped}/ms");

    var resultsLocation = await task.resultLocation;
    String objectPathForResult = task.uniqueName;

    await gae_utils.CloudStorage.writeFileBytes(
      resultsLocation.bucketName, objectPathForResult,
      UTF8.encode(response));

    // await gae_utils.CloudStorage.writeFileContents(
    //   resultsLocation.bucketName, objectPathForResult).addStream(
    //     new Stream.fromIterable(UTF8.encode(response)));

    elasped = sw.elapsedMilliseconds;
    _log.finer("PERF: Result uploaded ${elasped}/ms");

    await task.setState(tasks.LifecycleState.DONE);

    // TODO: Move this into the task API rather than needing to edit
    // the backing object
    task.backingstore.resultCloudStorageObjectPath = objectPathForResult;
    await task.recordProgress();

    elasped = sw.elapsedMilliseconds;
    _log.finer("Task $task Done: ${elasped}/ms");

  } catch (e, st) {
    _log.info("Worker threw an exception: $e\n$st");

    // TODO: Model with failure count
    task.setState(tasks.LifecycleState.DEAD);
  }
}

_ensureSourceIsInstalled(Map<String, String> codeMap) {
  String sha = computeCodeSha(codeMap);

  if (sha == shaCodeRunningInIsolate) {
    _log.finest("Code already installed: $sha");
    // The right code is already installed and hot
    return;
  }

  // Shutdown the existing isolate
  _log.finest("Killing existing isolate");
  if (isolate != null) {
    isolate.kill();
    isolate = null;
  }

  // Write the code to the folder
  for (String sourceName in codeMap.keys) {
    new io.File("$workerFolder$sourceName").writeAsStringSync(codeMap[sourceName]);
  }
  _setupIsolate("$workerFolder$START_NAME");

  _log.fine("Isolate started with sha: $sha");
  shaCodeRunningInIsolate = sha;
}

_setupIsolate(String startPath) async {
  _log.fine("_setupIsolate: $startPath");
  sendPort = null;
  receivePort = new ReceivePort();
  resultsController = new StreamController();
  resultsStream = resultsController.stream.asBroadcastStream();

  _log.finest("About to bind to recieve port");
  receivePort.listen((msg) {
    if (sendPort == null) {
      _log.finest("send port recieved");
      sendPort = msg;
    } else {
      resultsController.add(msg);
    }
  });

  isolate =
      await Isolate.spawnUri(Uri.parse(startPath), [], receivePort.sendPort);
  isolate.setErrorsFatal(false);
  _log.info("Worker isolate spawned");
}
