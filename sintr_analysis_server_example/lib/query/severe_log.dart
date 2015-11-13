// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.query.failures;

import 'package:sintr_worker_lib/instrumentation_query.dart';

const GET_CONTENTS_FAILED = 'GetContentsFailed';
const GET_CONTENTS_FAILED_PREFIX =
    'Internal error while performing the task: get contents of ';
const SEVERE_LOG = 'SevereLog';

/// Add an extraction result to the overall [results]
/// where [extracted] is produced by [SessionLdapMapper].
final severeLogReducer = (String sdkVersion, List logData, Map results) {
  // Extract log data
  var sessionId = logData[0];

  // Extract current results
  Map sdkResults = results.putIfAbsent(sdkVersion, () => {});
  Map sessionCounts = sdkResults.putIfAbsent('sessions', () => {});
  sessionCounts.putIfAbsent(sessionId, () => 0);
  ++sessionCounts[sessionId];
  sdkResults['total'] = sessionCounts.values.fold(0, (c1, c2) => c1 + c2);

  // Update current results
  return results;
};

/// [GetContentsFailedMapper] processes session log messages
/// and extracts severe log messages starting with
/// 'Internal error while performing the task: get contents of '.
///
/// Results keys are [sdkVersion] and values are a list containing
///
/// * [sessionId]
/// * failure time (ms since epoch)
/// * failure type (GET_CONTENTS_FAILED)
/// * uri
///
class GetContentsFailedMapper extends _AbstractFailureMapper {
  @override
  void mapLogMessage(int time, String msgType, String logMessageText) {
    if (msgType == 'Log') {
      if (logMessageText.startsWith('SEVERE:')) {
        _processSevereLogMsg(time, logMessageText);
      }
    }
  }

  /// Extract exceptions and failures from SEVERE log messages
  void _processSevereLogMsg(int time, String logMessageText) {
    var start = logMessageText.indexOf(':', 7);
    var msgText = logMessageText.substring(start + 1).replaceAll('::', ':');

    // Record getContent failed messages
    if (msgText.startsWith(GET_CONTENTS_FAILED_PREFIX)) {
      var uri = msgText.substring(GET_CONTENTS_FAILED_PREFIX.length);
      _recordFailure(time, GET_CONTENTS_FAILED, uri);
      return;
    }
  }
}

/// [SevereLogMapper] processes session log messages
/// and extracts severe log messages that do NOT start with
/// 'Internal error while performing the task: get contents of '.
///
/// Results keys are [sdkVersion] and values are a list containing
///
/// * [sessionId]
/// * failure time (ms since epoch)
/// * failure type (SEVERE_LOG)
/// * log message
///
class SevereLogMapper extends _AbstractFailureMapper {
  @override
  void mapLogMessage(int time, String msgType, String logMessageText) {
    if (msgType == 'Log') {
      if (logMessageText.startsWith('SEVERE:')) {
        _processSevereLogMsg(time, logMessageText);
      }
    }
  }

  /// Extract exceptions and failures from SEVERE log messages
  void _processSevereLogMsg(int time, String logMessageText) {
    var start = logMessageText.indexOf(':', 7);
    var msgText = logMessageText.substring(start + 1).replaceAll('::', ':');

    // Record all except getContent failed messages
    if (!msgText.startsWith(GET_CONTENTS_FAILED_PREFIX)) {
      _recordFailure(time, SEVERE_LOG, msgText);
      return;
    }
  }
}

abstract class _AbstractFailureMapper extends InstrumentationMapper {
  void _recordFailure(int time, String resultType, [resultData]) {
    addResult(sdkVersion, [sessionId, time, resultType, resultData]);
  }
}
