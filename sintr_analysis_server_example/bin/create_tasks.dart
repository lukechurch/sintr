// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/logging_utils.dart';
import 'package:sintr_common/task_utils.dart' as task_utils;

main(List<String> args) async {
  setupLogging();

  if (args.length != 0) {
    print("Create tasks for workers");
    io.exit(1);
  }

  String projectId = "liftoff-dev";
  String inputDataBucket = "liftoff-dev-datasources-analysis-server-sessions-sorted";

  config.configuration = new config.Configuration(projectId,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await getAuthedClient();

  var stor = await new storage.Storage(client, projectId);
  List<storage.BucketEntry> entries = await stor
      .bucket(inputDataBucket)
      .list() //prefix: "analysis-server-sessions")
      .toList();

  List<String> objectPaths = entries.map((be) => be.name).toList();
  await task_utils.createTasks(inputDataBucket, objectPaths);
  print ("${objectPaths.length} tasks created");
}
