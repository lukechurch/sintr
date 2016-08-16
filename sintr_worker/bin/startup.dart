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
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/gae_utils.dart' as gae_utils;
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_common/source_utils.dart';
import 'package:sintr_common/tasks.dart' as tasks;
import 'package:path/path.dart' as path;

String workerFolder;
const START_NAME = "worker_isolate.dart";
const DELAY_BETWEEN_TASK_POLLS = const Duration(seconds: 60);
const MAX_SPIN_WAITS_FOR_SEND_PORT = 10000;

const CLOUDSTORE_MAX_DURATION = const Duration(seconds: 120);
const ALWAYS_RESET_ISOLATE = true;


// Worker properties.
SendPort sendPort;
ReceivePort receivePort;
Isolate isolate;

StreamController resultsController;
Stream resultsStream;
String shaCodeRunningInIsolate;

String lastSeenMd5 = null;
String cachedSourceJSON = null;

// var dbService;

main(List<String> args) async {
  if (args.length != 3) {
    print("Worker node for sintr");
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
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await auth.getAuthedClient();
  var dbService = new db.DatastoreDB(
      new datastore_impl.DatastoreImpl(client, "s~$projectName"));
  var sourceStorage = new storage.Storage(client, projectName);

  ss.fork(() async {
    storage.registerStorageService(sourceStorage);
    db.registerDbService(dbService);

    tasks.TaskController taskController = new tasks.TaskController(jobName);
    log.trace("Task loop starting");

    while (true) {
      var task = await taskController.getNextReadyTask();

      if (task == null) {
        log.info("Got null next ready task, sleeping");
        await new Future.delayed(DELAY_BETWEEN_TASK_POLLS);
        continue;
      }

      Stopwatch sw = new Stopwatch()..start();
      await _handleTask(task, jobName);
      log.perf("Task $task completed", sw.elapsedMilliseconds);
    }
  });
}

_handleTask(tasks.Task task, String jobName) async {
  log.trace("Starting task $task");

  Stopwatch sw = new Stopwatch()..start();
  try {
    await task.setState(tasks.LifecycleState.STARTED);

    log.trace("About to get source");
    String sourceJSON;

    gae_utils.CloudStorageLocation sourceLocation = await task.sourceLocation;
    if (lastSeenMd5 != null && sourceLocation.md5 == lastSeenMd5) {
      log.trace("Source JSON cache hit: $lastSeenMd5");
      if (cachedSourceJSON == null) {
        throw "Invariant check failed: Cached key matched but source was null";
      }

      sourceJSON = cachedSourceJSON;
    } else {
      var oldMd5 = lastSeenMd5;

      log.trace("Loading source from: $sourceLocation");
      sourceJSON = await gae_utils.CloudStorage
          .getFileContentsByLocation(sourceLocation)
          .transform(UTF8.decoder)
          .join();
      lastSeenMd5 = sourceLocation.md5;
      cachedSourceJSON = sourceJSON;
      log.trace("Cache miss (was: $oldMd5): Source JSON acquired $lastSeenMd5");
    }

    var sourceMap = JSON.decode(sourceJSON);
    await _ensureSourceIsInstalled(sourceMap);
    log.trace("Source installed");

    gae_utils.CloudStorageLocation inputLocation = await task.inputSource;
    String messageJSON =
        JSON.encode([inputLocation.bucketName, inputLocation.objectPath, jobName]);

    int elasped = sw.elapsedMilliseconds;
    log.perf("Source acquired", elasped);

    log.trace("Sending: $messageJSON");
    sendPort.send(messageJSON);

    // TOOD: Replace this with a streaming write to cloud storage
    String response = await resultsStream.first;
    log.debug("Response: $response");

    elasped = sw.elapsedMilliseconds;
    log.perf("Response recieved", elasped);

    var resultsLocation = await task.resultLocation;

    // Decode the result
    var decodedResult = JSON.decode(response);

    var error = decodedResult["error"];

    if (error != null && decodedResult["result"] == null) {
        await gae_utils.CloudStorage.writeFileBytes(resultsLocation.bucketName,
            resultsLocation.objectPath + ".error", UTF8.encode(response)).timeout(CLOUDSTORE_MAX_DURATION);
            await task.setState(tasks.LifecycleState.DEAD);

        await _resetWorker("Error: $error");
    } else {
      await gae_utils.CloudStorage.writeFileBytes(resultsLocation.bucketName,
          resultsLocation.objectPath, UTF8.encode(response)).timeout(CLOUDSTORE_MAX_DURATION);
          await task.setState(tasks.LifecycleState.DONE);
    }

    // await gae_utils.CloudStorage.writeFileContents(
    //   resultsLocation.bucketName, objectPathForResult).addStream(
    //     new Stream.fromIterable(UTF8.encode(response)));

    elasped = sw.elapsedMilliseconds;
    log.perf("Result uploaded", elasped);

    if (ALWAYS_RESET_ISOLATE) await _resetWorker("Always reset policy");

    // TODO: Move this into the task API rather than needing to edit
    // the backing object
    await task.recordProgress();

    elasped = sw.elapsedMilliseconds;
    log.perf("Task $task Done", elasped);
  } catch (e, st) {
    log.info("Worker threw an exception: $e\n$st");

    await _resetWorker("Error: $e");

    // TODO: Model with failure count
    task.setState(tasks.LifecycleState.DEAD);
  }
}

_ensureSourceIsInstalled(Map<String, String> codeMap) async {
  String sha = computeCodeSha(codeMap);

  log.trace("Performing _ensureSourceInstalled: $sha");

  if (isolate != null && sha == shaCodeRunningInIsolate) {
    log.debug("Code already installed: $sha");
    // The right code is already installed and hot
    return;
  }

  // Shutdown the existing isolate
  if (isolate != null) {
    _resetWorker("Code out of date");
  } else {
    log.debug("No existing isolate");
  }

  List<String> pubspecPathsToUpdate = <String>[];

  // Write the code to the folder
  // TODO: This needs corresponding teardown, otherwise we have to wipe the VMs
  // between each execution
  for (String sourceName in codeMap.keys) {
    //TODO: Path package

    String fullName = path.join(workerFolder, sourceName);
    io.File fileObj = new io.File(fullName);

    if (sourceName.toLowerCase().endsWith("pubspec.yaml")) {
      if (fileObj.existsSync() &&
          fileObj.readAsStringSync() == codeMap[sourceName]) {
        log.trace("$fullName unchanged, skipping");
        continue; // Pubspec on disk was exactly the same as in memory
      } else {
        log.trace("$fullName changed, Pub get will be needed");
        pubspecPathsToUpdate.add(fullName);
      }
    }

    log.trace("Writing: ${fileObj.path}");
    // Ensure that the folder structures are in place
    fileObj.createSync(recursive: true);
    fileObj.writeAsStringSync(codeMap[sourceName]);
  }

  if (pubspecPathsToUpdate.length > 0) _pubUpdate(pubspecPathsToUpdate);
  await _setupIsolate(path.join(workerFolder, START_NAME));

  log.debug("Isolate started with sha: $sha");
  shaCodeRunningInIsolate = sha;
}

_pubUpdate(List<String> pubspecPathsToUpdate) async {
  io.Directory orginalWorkingDirectory = io.Directory.current;

  for (String fullName in pubspecPathsToUpdate) {
    //TODO: Path package
    io.Directory.current = path.dirname(fullName);

    log.trace("In ${io.Directory.current.toString()} about to run pub get");
    io.ProcessResult result = await io.Process.runSync("pub", ["get"]);
    log.trace("Pub get complete: exit code: ${result.exitCode} \n"
        " stdout:\n${result.stdout} \n stderr:\n${result.stderr}");
  }
  io.Directory.current = orginalWorkingDirectory;
}

_setupIsolate(String startPath) async {
  log.debug("isolate == null: ${isolate == null}");
  log.debug("_setupIsolate: $startPath");
  sendPort = null;
  receivePort = new ReceivePort();
  resultsController = new StreamController();
  resultsStream = resultsController.stream.asBroadcastStream();

  log.debug("About to bind to recieve port");
  receivePort.listen((msg) {
    log.trace("recievePort message: $msg");

    if (sendPort == null) {
      log.debug("send port recieved");
      sendPort = msg;
    } else {
      resultsController.add(msg);
    }
  });
  log.debug("About to spawn isolate");
  isolate =
      await Isolate.spawnUri(
        Uri.parse(startPath),
        [],
        receivePort.sendPort,
        errorsAreFatal: false,
      automaticPackageResolution : true);
  log.debug("Isolate spawned");
  int spinCounter = 0;
  while (sendPort == null && spinCounter++ < MAX_SPIN_WAITS_FOR_SEND_PORT) {
    log.debug("About to poll wait: $spinCounter");
    await new Future.delayed(new Duration(milliseconds: 1));
    log.debug("Spinning waiting for send port: $spinCounter");
  }

  if (sendPort == null) {
    throw "sendPort was not recieved after $MAX_SPIN_WAITS_FOR_SEND_PORT waits";
  }
  log.info("Worker isolate spawned");
}

_resetWorker(String cause) async {
  log.debug("Restarting isolate due to: $cause");
  log.debug("About to kill, isolate == null: ${isolate == null}");
  isolate?.kill(priority: Isolate.IMMEDIATE);
  isolate = null;

  log.debug("ResultsStream == null: ${resultsStream == null}");
  resultsController.close();
  await resultsStream?.drain();
  log.debug("Isolate now null");
}
