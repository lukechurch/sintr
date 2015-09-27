// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dm_feature_server.gae_utils;

import 'dart:async';

import 'package:appengine/appengine.dart' as ae;
import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/logging_utils.dart' as logging;
import 'package:memcache/memcache.dart' as mc;

final _logger = new logging.Logger("gae_utils");

/// Wrap memcache in an error absorbing wrapper.
class SafeMemcache {
  // static get _memcache => ae.context.services.memcache;

  static mc.Memcache get _memcache => ae.context.services.memcache;

  static Future<String> get(String key) => _ignoreErrors(_memcache.get(key));

  static Future set(String key, String value, {Duration expiration}) =>
      _ignoreErrors(_memcache.set(key, value, expiration: expiration));

  static Future remove(String key) => _ignoreErrors(_memcache.remove(key));

  static Future _ignoreErrors(Future f) {
    return f.catchError((error, stackTrace) {
      _logger.fine(
          'Soft-ERR memcache API call (error: $error)', error, stackTrace);
    });
  }
}

/// Support utils for clous storage buckets. They expect to be run in a service
/// fork.
class CloudStorage {
  static Stream<List<int>> getFileContents(String bucketName, String objectPath) =>
    storage.storageService.bucket(bucketName).read(objectPath);

  static Stream<List<int>> getFileContentsByLocation(CloudStorageLocation location) =>
    getFileContents(location.bucketName, location.objectPath);


  static StreamSink<List<int>> writeFileContents(String bucketName, String objectPath) =>
    storage.storageService.bucket(bucketName).write(objectPath);

  static StreamSink<List<int>> writeFileContentsByLocation(CloudStorageLocation location) =>
    writeFileContents(location.bucketName, location.objectPath);

static Future writeFileBytes(String bucketName, String objectPath, List<int> data) =>
  storage.storageService.bucket(bucketName).writeBytes(objectPath, data);

  static Future writeFileBytesByLocation(CloudStorageLocation location, List<int> data) =>
    writeFileBytes(location.bucketName, location.objectPath, data);

}


class CloudStorageLocation {
  final String bucketName;
  final String objectPath;

  CloudStorageLocation(this.bucketName, this.objectPath);
}
