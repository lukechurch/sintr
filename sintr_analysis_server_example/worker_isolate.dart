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
import 'package:sintr_worker_lib/instrumentation_lib.dart';

const projectName = "liftoff-dev";

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
    var logItems = [];
    var errItems = [];
    int failureCount = 0;
    int lines = 0;

    LogItemProcessor proc = new LogItemProcessor(extractPerf);

    Stream dataStream = await getDataFromCloud(bucketName, objectPath);
    await for (String s in dataStream) {
      lines++;
      try {
        proc.addRawLine(s);

        String nextMessage;
        while (proc.hasMoreMessages) {
          nextMessage = proc.readNextMessage();
          if (nextMessage != null) logItems.add(nextMessage);
        }
      } catch (e, st) {
        log.info("Message proc erred. $e \n $st \n");
        errItems
            .add({"lastBlock": false, "rawDataLine": s, "exception": "$e", "stackTrace": "$st"});
        failureCount++;
      }
    }

    try {
      proc.close();

      String nextMessage;
      while (proc.hasMoreMessages) {
        nextMessage = proc.readNextMessage();
        if (nextMessage != null) logItems.add(nextMessage);
      }
    } catch (e, st) {
      log.info("Message proc erred. $e \n $st \n");
      errItems
          .add({"lastBlock": true, "exception": "$e", "stackTrace": "$st"});
      failureCount++;
    }

    return JSON.encode({
      "result": logItems,
      "failureCount": failureCount,
      "errItems": errItems,
      "linesProcessed": lines,
      "input": "gs://$bucketName/$objectPath"
    });
  } catch (e, st) {
    log.info("Message proc erred. $e \n $st \n");
    log.debug("Input data: $msg");
    return JSON.encode({"error": "${e}", "stackTrace": "${st}"});
  }
}

Future<Stream<List<String>>> getDataFromCloud(
    String bucketName, String objectPath) async {
  config.configuration = new config.Configuration(projectName,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await auth.getAuthedClient();
  var sourceStorage = new storage.Storage(client, projectName);
  Stream<List<int>> rawStream =
      sourceStorage.bucket(bucketName).read(objectPath);
  Stream<List<String>> stringStream =
      rawStream.transform(UTF8.decoder).transform(new LineSplitter());
  return stringStream;
}
