// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_common/task_utils.dart' as task_utils;
import 'package:sintr_common/gae_utils.dart';

import 'package:sintr_worker_lib/job_config.dart' as jobs;


const VERBOSE_LOGGING = false;

main(List<String> args) async {
  log.setupLogging();
  bool include = true;

  // TODO(lukechurch): This is getting silly. args package.
  if (args.length < 2) {
    print("Create tasks for workers");
    print("Usage: dart create_tasks.dart <job_name> <incremental_string>");
    io.exit(1);
  }

  String jobName = args[0];
  String incrementalString = args[1];

  var jobConfig = jobs.jobMap[jobName];
  String filterString = jobConfig.filter;

  bool incremental = null;

  switch (incrementalString.toLowerCase()) {
    case "false":
      incremental = false;
      break;
    case "true":
      incremental = true;
      break;
    default:
      print("Unknown incremental string: $incrementalString");
      io.exit(1);
  }

  if (filterString.startsWith("!")) {
    include = false;
    filterString = filterString.substring(1);
  }

  if (include) {
    log.info("Including $filterString");
  } else {
    log.info("Excluding $filterString");
  }

  String projectId = "liftoff-dev";
  String inputDataBucket =
      "liftoff-dev-datasources-analysis-server-sessions-sorted";

  config.configuration = new config.Configuration(projectId,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  log.trace("About to get client");

  var client = await getAuthedClient();

  var stor = await new storage.Storage(client, projectId);

  var bucketSet = await listBucket(stor.bucket(inputDataBucket));
  var objectPaths = bucketSet.toList();

  if (filterString != null) {
    if (include) {
      objectPaths = objectPaths.where((p) => p.contains(filterString)).toList();
    } else {
      objectPaths = objectPaths.where((p) => !p.contains(filterString)).toList();
    }
  }

  if (VERBOSE_LOGGING) {
    print("Input Paths");
    for (var path in objectPaths) {
      print (path);
    }
  }

  await task_utils.createTasks(jobName, inputDataBucket, objectPaths,
      "liftoff-dev-results", "liftoff-dev-source", incremental: incremental);
}
