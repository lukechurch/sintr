// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:gcloud/service_scope.dart' as ss;
import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import "package:sintr_common/gae_utils.dart" as gae_utils;
import 'package:sintr_common/logging_utils.dart';

main(List<String> args) async {
  setupLogging();

  if (args.length != 4) {
    print ("Pack and upload source for sintr_worker");
    print("Usage: dart uploadSource.dart project_name bucket_name object_name path");
    print(args);
    io.exit(1);
  }

  String projectName = args[0];
  String bucketName = args[1];
  String objectName = args[2];
  String path = args[3];

  config.configuration = new config.Configuration(projectName,
      cryptoTokensLocation: "${config.userHomePath}/Communications/CryptoTokens");

  var client = await getAuthedClient();

  ss.fork(() async {
    storage.registerStorageService(new storage.Storage(client, projectName));

    String source = new io.File(path).readAsStringSync();
    var json = JSON.encode({"worker_isolate.dart" : source});

    List<int> bytes = UTF8.encode(json);

    await gae_utils.CloudStorage.writeFileBytes(bucketName, objectName, bytes);

    info ("Upload done");
  });
}
