// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library analysis_proc.bucket_util.test;

import 'dart:io';

import 'package:gcloud/storage.dart' as storage;
import 'package:googleapis_auth/auth.dart' as auth;
import 'package:googleapis_auth/auth_io.dart' as auth_io;
import 'package:sintr_worker_lib/bucket_util.dart';

main(List<String> args) async {
  // Extract cmdline arguments
  if (args.length < 4) {
    print("Usage: test authKeyFile projectName srcBucketName cloudFileName");
    exit(1);
  }
  var authKeyFilePath = args[0];
  var projectName = args[1];
  var bucketName = args[2];
  var cloudFileName = args[3];

  // Connect to Google Cloud
  var scopes = <String>[]..addAll(storage.Storage.SCOPES);
  var client = await auth_io.clientViaServiceAccount(
      new auth.ServiceAccountCredentials.fromJson(
          new File(authKeyFilePath).readAsStringSync()),
      scopes);

  // Process the file
  await processFile(client, projectName, bucketName, cloudFileName,
      (String logEntry) {
    print(logEntry);
  }, (ex, st) {
    print(ex);
    print(st);
  });

  // Cleanup
  client.close();
}
