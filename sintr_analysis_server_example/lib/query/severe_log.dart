// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.query.failures;

import 'package:sintr_worker_lib/instrumentation_query.dart';

const SEVERE_LOG = 'SevereLog';

/// Add an extraction result to the overall [results]
/// where [extracted] is produced by [SevereLogMapper].
final severeLogReducer = (String sdkVersion, List logData, Map results) {
  // Extract log data
  var sessionId = logData[0];
  var eventTime = new DateTime.fromMillisecondsSinceEpoch(logData[1]);
  var eventDate = "${eventTime.year}-${eventTime.month}-${eventTime.day}";

  // Extract current results
  Map dateResults = results.putIfAbsent(eventDate, () => {});
  Map sdkResults = dateResults.putIfAbsent(sdkVersion, () => {});
  sdkResults.putIfAbsent(sessionId, () => 0);
  ++sdkResults[sessionId];

  // Update current results
  return results;
};

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
    _recordFailure(time, SEVERE_LOG, msgText);
  }
}

abstract class _AbstractFailureMapper extends InstrumentationMapper {
  static const MAX_TIMES_TO_REPORT = 1000 * 1000;

  // type -> data -> times
  Map<String, Map<String, List<int>>> typeResultsTimes = {};
  Map<String, Map<String, int>> typeResultsCounts = {};

  void _recordFailure(int time, String resultType, String resultData) {
    String data = resultData.split('\n')[0];

    typeResultsTimes.putIfAbsent(resultType, () => {});
    typeResultsCounts.putIfAbsent(resultType, () => {});

    Map<String, List<int>> resultTimes = typeResultsTimes[resultType];
    Map<String, int> resultCounts = typeResultsCounts[resultType];

    resultTimes.putIfAbsent(data, () => []);
    resultCounts.putIfAbsent(data, () => 0);

    int count = resultCounts[data]++;
    if (count < MAX_TIMES_TO_REPORT) {
      resultTimes[data].add(time);
    }
  }

  @override
  void cleanup() {
    for (String typeResult in typeResultsTimes.keys) {
      var times = typeResultsTimes[typeResult];
      var counts = typeResultsCounts[typeResult];

      addResult(sdkVersion, [typeResult, {
        "times": times,
        "counts:": counts}]);
    }
  }
}
