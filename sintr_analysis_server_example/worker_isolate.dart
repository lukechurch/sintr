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
  var processor = new LogItemProcessor();

  try {
    var inputData = JSON.decode(msg);
    String bucketName = inputData[0];
    String objectPath = inputData[1];
    var logItems = [];
    int failureCount = 0;

    Stream dataStream = await getDataFromCloud(bucketName, objectPath);
    await for (String s in dataStream) {
      try {
        String result = processor.processLine(s);
        if (result != null) logItems.add(result);
      } catch (e, st) {
        failureCount++;
      }
    }

    try {
      String result = processor.close();
      if (result != null) logItems.add(result);
    } catch (e, st) {
      failureCount++;
    }

    return JSON.encode({"result": logItems, "failureCount": failureCount});
  } catch (e, st) {
    log.info("Execution erred. $e \n $st \n");
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
