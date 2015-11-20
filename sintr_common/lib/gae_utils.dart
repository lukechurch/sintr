// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dm_feature_server.gae_utils;

import 'dart:async';
import 'package:gcloud/storage.dart' as storage;
import 'logging_utils.dart' as log;

/// Support utils for cloud storage buckets. They expect to be run in a service
/// fork.
class CloudStorage {
  static Stream<List<int>> getFileContents(
      String bucketName, String objectPath) {
    if (storage.storageService == null) {
      throw "Cannot access CloudStorage outside service scope";
    }

    return storage.storageService.bucket(bucketName).read(objectPath);
  }

  static Stream<List<int>> getFileContentsByLocation(
          CloudStorageLocation location) =>
      getFileContents(location.bucketName, location.objectPath);

  static StreamSink<List<int>> writeFileContents(
          String bucketName, String objectPath) =>
      storage.storageService.bucket(bucketName).write(objectPath);

  static StreamSink<List<int>> writeFileContentsByLocation(
          CloudStorageLocation location) =>
      writeFileContents(location.bucketName, location.objectPath);

  static Future writeFileBytes(
          String bucketName, String objectPath, List<int> data) =>
      storage.storageService.bucket(bucketName).writeBytes(objectPath, data);

  static Future writeFileBytesByLocation(
          CloudStorageLocation location, List<int> data) =>
      writeFileBytes(location.bucketName, location.objectPath, data);
}

class CloudStorageLocation {
  final String bucketName;
  final String objectPath;

  /// Optional: If this is included it should be a base64 encoding of the MD5
  /// from cloud storage, this can be used to determine whether the sytem
  /// already has a copy of the file, or whether it has changed
  final String md5;

  CloudStorageLocation(this.bucketName, this.objectPath, [this.md5]);
}

Future<Set<String>> listBucket(storage.Bucket bucket) async {
  const PAGE_SIZE = 2000;

  Set<String> names = new Set<String>();
  storage.Page page = await bucket.page(pageSize: PAGE_SIZE);

  while (!page.isLast) {
    names.addAll(page.items.map((x) => x.name));
    log.trace("names count: ${names.length}");
    page = await page.next(pageSize: PAGE_SIZE);
  }
  names.addAll(page.items.map((x) => x.name));

  return names;
}
