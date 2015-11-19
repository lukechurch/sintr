// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/auth.dart';
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_worker_lib/instrumentation_transformer.dart';
import 'package:sintr_worker_lib/query/completion_metrics.dart';
import 'package:sintr_worker_lib/session_info.dart';

const projectName = "liftoff-dev";
var client;

Future main(List<String> args, SendPort sendPort) async {
  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) async {
    sendPort.send(await _protectedHandle(msg));
  });
}

Future<String> _protectedHandle(String msg) async {
  try {
    var inputData = JSON.decode(msg);
    String bucketName = inputData[0];
    String objectPath = inputData[1];
    var results = [];
    var errItems = [];
    int failureCount = 0;
    int lines = 0;

    // Initialize query specific objects
    var mapper = new CompletionMapper();

    // Completion query specific logic =============

    // Skip PRI files
    if (objectPath.contains("PRI")) {
      return JSON.encode({
        "result": [],
        "failureCount": 0,
        "errItems": [],
        "linesProcessed": 0,
        "input": "gs://$bucketName/$objectPath"
      });
    }

    // Get the session info
    var pathComponents = objectPath.split("/");
    var sessionId = pathComponents.removeLast();
    pathComponents.add("PRI${sessionId}");
    String guessedPRIPath = pathComponents.join("/");

    Stream priDataStream = await getDataFromCloud(bucketName, guessedPRIPath);
    var sessionInfo = await readSessionInfo(sessionId, priDataStream);

    // ===================

    Stream dataStream = await getDataFromCloud(bucketName, objectPath);

    // Extraction
    await mapper.init(sessionInfo, (String key, value) {
      results.add([key, value]);
    });
    await for (String logEntry in dataStream
        .transform(UTF8.decoder)
        .transform(new LineSplitter())
        .transform(new LogItemTransformer())
        .handleError((e, s) {
      failureCount++;
      errItems.add("Error reading line\n${trim300(e.toString())}\n$s");
    })) {
      lines++;
      // TODO (lukechurch): Add local error capture here
      mapper.map(logEntry);
      if (mapper.isMapStopped) break;
    }
    mapper.cleanup();

    return JSON.encode({
      "result": results,
      "failureCount": failureCount,
      "errItems": errItems,
      "linesProcessed": lines,
      "input": "gs://$bucketName/$objectPath",
      "mapperStoppedBeforeEnd": mapper.isMapStopped
    });
  } catch (e, st) {
    log.info("Message proc erred. $e \n $st \n");
    log.debug("Input data: $msg");
    return JSON.encode({"error": "${e}", "stackTrace": "${st}"});
  }
}

Future<Stream<List<int>>> getDataFromCloud(
    String bucketName, String objectPath) async {
  config.configuration = new config.Configuration(projectName,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  client = await auth.getAuthedClient();
  var sourceStorage = new storage.Storage(client, projectName);
  Stream<List<int>> rawStream =
      sourceStorage.bucket(bucketName).read(objectPath);
  return rawStream;
}
