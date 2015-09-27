// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dm_feature_server.file_based_feature_cache;

import 'dart:async';

import 'package:appengine/appengine.dart' as ae;
import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/logging_utils.dart' as logging;

final _logger = new logging.Logger("gae_utils");

/// Wrap memcache in an error absorbing wrapper.
class SafeMemcache {
  static get _memcache => ae.context.services.memcache;

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

  static StreamSink<List<int>> writeFileContents(String bucketName, String objectPath) =>
    storage.storageService.bucket(bucketName).write(objectPath);
}
