// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_common/gae_utils.dart';

const DART_USAGE_PROJ = "dart-usage";
const LIFTOFF_PROJ = "liftoff-dev";

  const frontEndBufferBucket = "dart-analysis-server-sessions";
  const sortedBucket = "dart-analysis-server-sessions-sorted";
  const liftOffBucket =
      "liftoff-dev-datasources-analysis-server-sessions-sorted";


main(List<String> args) async {
  log.setupLogging();

  if (args.length != 0) {
    print("List bucket states");
    print("Usage: dart bucket_status.dart");
    io.exit(1);
  }

  Map<String, int> counts = {};

  config.configuration = new config.Configuration(DART_USAGE_PROJ,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  log.trace("About to get client: $DART_USAGE_PROJ");

  var client = await getAuthedClient();

  var stor = await new storage.Storage(client, DART_USAGE_PROJ);

  log.trace("About to list $frontEndBufferBucket");
  var frontEndBufferBucketSet = await listBucket(stor.bucket(frontEndBufferBucket));
  counts[frontEndBufferBucket] = frontEndBufferBucketSet.length;

  log.trace("About to list $sortedBucket");
  var sortedBucketSet = await listBucket(stor.bucket(sortedBucket));
  counts[sortedBucket] = sortedBucketSet.length;



  config.configuration = new config.Configuration(LIFTOFF_PROJ,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");
  log.trace("About to get client: $LIFTOFF_PROJ");
  client = await getAuthedClient();
  stor = await new storage.Storage(client, LIFTOFF_PROJ);

  log.trace("About to list $liftOffBucket");
  var liftOffBucketSet = await listBucket(stor.bucket(liftOffBucket));
  counts[liftOffBucket] = liftOffBucketSet.length;

  print (counts);
}
