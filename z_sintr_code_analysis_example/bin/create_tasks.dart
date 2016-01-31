// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_common/task_utils.dart' as task_utils;
import 'package:sintr_common/gae_utils.dart';



const VERBOSE_LOGGING = false;

main(List<String> args) async {
  log.setupLogging();

  String projectId = "liftoff-dev";
  String inputDataBucket =
      "liftoff-dev-datasources-src";

  config.configuration = new config.Configuration(projectId,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  log.trace("About to get client");

  var client = await getAuthedClient();

  var stor = await new storage.Storage(client, projectId);

  var bucketSet = await listBucket(stor.bucket(inputDataBucket));
  var objectPaths = bucketSet.toList();

  if (VERBOSE_LOGGING) {
    print("Input Paths");
    for (var path in objectPaths) {
      print (path);
    }
  }

  await task_utils.createTasks("DartpadAnalysis", inputDataBucket, objectPaths,
      "liftoff-dev-results", "liftoff-dev-source", incremental: true);
}
