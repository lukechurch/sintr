// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:gcloud/db.dart' as db;
import 'package:gcloud/src/datastore_impl.dart' as datastore_impl;
import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/auth.dart';
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/logging_utils.dart' as log;


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

    String data = await getDataFromCloud(bucketName, objectPath);
    var counts = <String, int>{};
    RegExp exp = new RegExp(r"[^a-zA-Z]+");

    for (String str in data.split(exp)){
      counts.putIfAbsent(str, () => 0);
      counts[str]++;
    }

    return JSON.encode({"result" : counts});

  } catch (e, st) {
    log.info("Execution erred. $e \n $st \n");
    log.debug("Input data: $msg");
    return JSON.encode({});
  }
}

Future<String> getDataFromCloud(String bucketName, String objectPath) async {

  config.configuration = new config.Configuration(projectName,
      cryptoTokensLocation: "${config.userHomePath}/Communications/CryptoTokens");

    var client = await auth.getAuthedClient();
    var dbService = new db.DatastoreDB(new datastore_impl.DatastoreImpl(client, "s~$projectName"));
    var sourceStorage = new storage.Storage(client, projectName);
    return sourceStorage.bucket(bucketName).read(objectPath).transform(UTF8.decoder).join();
}
