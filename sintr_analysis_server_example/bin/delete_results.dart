// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/gae_utils.dart' as gae;
import 'package:sintr_common/logging_utils.dart';
import 'package:sintr_common/logging_utils.dart' as log;

const VERBOSE_LOGGING = false;

main(List<String> args) async {
  setupLogging();

  if (args.length != 1) {
    print("Clear delete all previous results for a given job");
    print("Usage dart job_name");
    io.exit(1);
  }

  String resultsFolder = args[0];
  String projectId = "liftoff-dev";
  String resultsBucket = "liftoff-dev-results";

  config.configuration = new config.Configuration(projectId,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await getAuthedClient();

  var stor = await new storage.Storage(client, projectId);

  Set<String> names = await gae.listBucket(
    stor.bucket(resultsBucket), prefix: resultsFolder);

  log.info("Results listed ${names.length}");

  List<Future> deleteFutures = [];

  int i = 0;
  const BLOCK_COUNT = 150;

  for (var name in names) {
    log.info("About to delete $name");

    deleteFutures.add(stor.bucket(resultsBucket).delete(name));
    if (i++ % BLOCK_COUNT == 0) {
      for (Future f in deleteFutures) {
        await f;
      }
      if (VERBOSE_LOGGING) log.info("Deleted: $i");
    }
  }
  for (Future f in deleteFutures) {
    await f;
  }

  log.info("Old results deleted");
}
