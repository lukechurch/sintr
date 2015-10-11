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
import 'package:path/path.dart' as path_utils;

main(List<String> args) async {
  setupLogging();

  if (args.length != 4) {
    print("Pack and upload source for sintr_worker");
    print(
        "Usage: dart uploadSource.dart project_name bucket_name object_name path");
    print(args);
    io.exit(1);
  }

  String projectName = args[0];
  String bucketName = args[1];
  String objectName = args[2];
  String path = args[3];

  if (path.endsWith('/')) {
    print ("Please use unterimanted paths");
    io.exit(1);
  }

  var dartFiles = new io.Directory(path)
      .listSync(recursive: true)
      .where((fse) => fse.path.endsWith(".dart"));

  // Compute paths relative to the source
  // -> Sub path, strip '/' from the start
  var relativePaths = dartFiles
      .map((fse) => fse.path.split(path)[1].substring(1))
      .where((p) => !(p.contains('packages') || p.contains('.pub')))
      .toList();

  config.configuration = new config.Configuration(projectName,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await getAuthedClient();

  ss.fork(() async {
    storage.registerStorageService(new storage.Storage(client, projectName));

    var sourceMap = {};

    for (String relativePath in relativePaths) {
      sourceMap.putIfAbsent(
          relativePath, () => new io.File("$path/$relativePath").readAsStringSync());
    }
    var json = JSON.encode(sourceMap);

    List<int> bytes = UTF8.encode(json);

    await gae_utils.CloudStorage.writeFileBytes(bucketName, objectName, bytes);

    info("Upload done");
  });
}
