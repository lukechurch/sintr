// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library analysis_proc.bucket_util;

import 'dart:async';
import 'dart:convert';

import 'package:gcloud/storage.dart';
import 'package:googleapis_auth/auth.dart';
import 'instrumentation_transformer.dart';

final _TIMEOUT = new Duration(seconds: 600);

/// Process [fileName] from [srcBucket] using [onData].
/// [onError] is called with the exception and stack trace
/// if an exception occurs when reading or translating.
/// Return a [Future] that completes when processing is complete.
Future processFile(
    AuthClient client,
    String projectName,
    String bucketName,
    String cloudFileName,
    void onData(String logEntry),
    void onError(exception, stackTrace)) async {
  // Call listen to start the download, but use subscription methods
  // so that the onData, onError, and onDone methods are correctly attached.
  StreamSubscription subscription = new Storage(client, projectName)
      .bucket(bucketName)
      .read(cloudFileName)
      .timeout(_TIMEOUT)
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .transform(new LogItemTransformer(allowNonSequentialMsgs: true))
      .handleError(onError)
      .listen(null);

  // Pause the stream when processing entries
  // to prevent out of memory exception.
  subscription.onData((String logEntry) {
    subscription.pause();
    try {
      onData(logEntry);
    } catch (e, s) {
      if (e is StopProcessingFile) {
        subscription.cancel();
      } else {
        onError(e, s);
      }
    }
    subscription.resume();
  });

  // Handle subscription level errors
  subscription.onError(onError);

  // Return a future that completes when all entries have been processed
  var completer = new Completer();
  subscription.onDone(completer.complete);
  return completer.future;
}

/// If the onData callback in the [procecessFile] method throws
/// an instance of [StopProcessingFile] then [processFile] cancels processing.
class StopProcessingFile {}
