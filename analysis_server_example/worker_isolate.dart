// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/logging_utils.dart' as log;
import 'lib/bucket_util.dart';
import 'lib/instrumentation_transformer.dart';

import 'lib/session_info.dart';
import 'lib/job_config.dart' as jobs;


const projectName = "liftoff-dev";

var client;

Future main(List<String> args, SendPort sendPort) async {
  log.setupLogging("sintr:z_analysis_server_example:worker_isolate");

  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) async {
    sendPort.send(await _protectedHandle(msg));
  });
}

Future<String> _protectedHandle(String msg) async {
  log.trace("Begin _protectedHandle: $msg");

  try {
    var inputData = JSON.decode(msg);
    String bucketName = inputData[0];
    String objectPath = inputData[1];
    var results = [];
    var errItems = [];
    int failureCount = 0;
    int lines = 0;

    // Initialize query specific objects
    var mapper = jobs.severeLogsAll.mapper;
    var needsSessionInfo = jobs.severeLogsAll.needsSessionInfo;

    // Cloud connect
    config.configuration = new config.Configuration(projectName,
        cryptoTokensLocation:
            "${config.userHomePath}/Communications/CryptoTokens");
    client = await auth.getAuthedClient();

    log.trace("Client acquired");

    var sessionInfo = null;
    if (needsSessionInfo) {
      log.trace("Getting sessionInfo");


      // Get the session info
      var pathComponents = objectPath.split("/");
      var sessionId = pathComponents.removeLast();
      pathComponents.add("PRI${sessionId}");
      String guessedPRIPath = pathComponents.join("/");

      await processFile(client, projectName, bucketName, guessedPRIPath,
          (String logEntry) {
        if (sessionInfo == null) {
          sessionInfo = parseSessionInfo(sessionId, logEntry);
          print ("SessionInfo acquired: $sessionInfo");

        }
      }, (ex, st) {
        errItems.add("Session info erred. ${trim300(ex.toString())} \n $st \n");
      });
      if (sessionInfo == null) {
        return JSON.encode({
          "result": [],
          "failureCount": 1,
          "errItems": errItems,
          "linesProcessed": 0,
          "input": "gs://$bucketName/$objectPath"
        });
      }
    }

    log.trace ("SessionInfo before init: $sessionInfo");

    // Extraction
    await mapper.init(sessionInfo, (String key, value) {
      results.add([key, value]);
    });
    await processFile(client, projectName, bucketName, objectPath,
        (String logEntry) {
      lines++;
      mapper.map(logEntry);
      if (mapper.isMapStopped) throw new StopProcessingFile();
    }, (ex, st) {
      failureCount++;
      errItems.add("Message proc erred. ${trim300(ex.toString())} \n $st \n");
    });
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
    if (client != null) client.close();
    log.info("Message proc erred. $e \n $st \n");
    log.debug("Input data: $msg");
    return JSON.encode({"error": "${e}", "stackTrace": "${st}"});
  }
}
