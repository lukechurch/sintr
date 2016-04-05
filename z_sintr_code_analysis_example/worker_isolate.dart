// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';

import "package:googleapis_auth/auth_io.dart";

import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:gcloud/storage.dart' as storage;

import 'package:sintr_common/bucket_utils.dart';
import 'analyse_path.dart';
import 'package:path/path.dart' as path;

const PROJECT_NAME = "liftoff-dev";
const PATH_NAME = "data_working";

var client;

Future main(List<String> args, SendPort sendPort) async {
  log.setupLogging("worker_isolate");

  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) async {
    sendPort.send(await _protectedHandle(msg));
  });
}

Future<String> _protectedHandle(String msg) async {
  log.trace("Begin _protectedHandle");
  try {
    var inputData = JSON.decode(msg);
    String bucketName = inputData[0];
    String objectPath = inputData[1];

    // Cloud connect
    config.configuration = new config.Configuration(PROJECT_NAME,
        cryptoTokensLocation:
            "${config.userHomePath}/Communications/CryptoTokens");
    client = await auth.getAuthedClient();

    var results = await processFile(client, PROJECT_NAME, bucketName, objectPath);

    return JSON.encode({
      "result": results,
      "input": "gs://$bucketName/$objectPath",
    });
  } catch (e, st) {
    if (client != null) client.close();
    log.info("Message proc erred. $e \n $st \n");
    log.debug("Input data: $msg");
    return JSON.encode({"error": "${e}", "stackTrace": "${st}"});
  }
}


Future processFile(
    AuthClient client,
    String projectName,
    String bucketName,
    String cloudFileName) async {

      String workingPath = path.join(Platform.environment["HOME"], PATH_NAME);

      Directory workingDirectory = new Directory(workingPath);
      workingDirectory.createSync();

      var client = await auth.getAuthedClient();
      var sourceStorage = new storage.Storage(client, projectName);

      log.info("Downloading $bucketName/$cloudFileName");

      await downloadFile(
        sourceStorage.bucket(bucketName),
        cloudFileName,
        workingDirectory).timeout(new Duration(seconds: 300));

      log.info("Decompressing");
      workingDirectory = new Directory(workingPath);

      for (var f in workingDirectory.listSync(recursive: true)) {
        log.info("Testing: ${f.path}");

        if (f.path.endsWith(".tar.gz")) {
          log.info("Running untar");
          await Process.run("tar", ['xvf', f.path, '-C', workingDirectory.path]);
          log.info("Untar finished");
          new File(f.path).deleteSync();
          log.info("Original deleted");
        }
      }
      log.info("About to analyse");

      var results = await analyseFolder(workingDirectory.path);
      // var results = [workingDirectory.path];

      log.info("Cleaning up");


      log.info("Deleting working directory");

      workingDirectory.deleteSync(recursive: true);
      log.info("Deleted working directory");

      return results;
    }
