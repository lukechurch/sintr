// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO move these into a 4th library containing
// the MR and support functions specific to log processing

library sintr_common.instrumentation_utils;

import 'dart:async';
import 'dart:convert';

import 'package:gcloud/storage.dart';
import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/logging_utils.dart' as logging;

var PROJECT = 'sintr-994';

final _log = new logging.Logger("instrumentation_utils");

/// Open a stream on the given instrumentation log
Future<Stream<String>> logStream(logKey) async {
  var client = await auth.getAuthedClient();
  _log.finest("Client acquired");

  var storage = new Storage(client, PROJECT);
  _log.finest("Storage acquired");

  return storage
  .bucket("sintr-sample-test-data")
  .read(logKey)
  .transform(UTF8.decoder) // Decode bytes to UTF8.
  .transform(new LineSplitter()); // Convert stream to individual lines.
}