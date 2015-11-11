// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.completion;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:sintr_worker_lib/instrumentation_query.dart';
import 'package:sintr_worker_lib/instrumentation_transformer.dart';
import 'package:sintr_worker_lib/query.dart';
import 'package:sintr_worker_lib/session_info.dart';

const AVE = 'ave';
const INCOMPLETE = 'incomplete';
const MAX = 'max';
const MIN = 'min';
const RESPONSE_TIME_BUCKETS = 'responseTimeBuckets';
const RESPONSE_TIMES = 'responseTimes';
const RESULT_COUNT_BUCKETS = 'resultCountBuckets';
const RESULT_COUNTS = 'resultCounts';
const TOTAL = 'total';
const V90TH = '90th';
const V99TH = '99th';
const VERSION = 'version';

/// Add an extraction result to the overall [results]
/// where [extracted] is the result of calling [_composeResult].
final completionReducer = (String sdkVersion, List extracted, Map results) {
  // Extract current results for SDK
  // version, min, ave, max, count, total, incomplete, etc
  int completionTime = extracted[0];
  int resultCount = extracted[1];
  var sdkResults = results[sdkVersion];
  if (sdkResults == null) {
    sdkResults = {
      VERSION: sdkVersion,
      RESPONSE_TIMES: [],
      RESULT_COUNTS: [],
      TOTAL: 0,
      //MIN: 0,
      //AVE: 0,
      //V90TH: 0,
      //V99TH: 0,
      //MAX: 0,
      INCOMPLETE: 0
    };
    results[sdkVersion] = sdkResults;
  }

  // Update results with new information
  if (completionTime > 0) {
    orderedInsert(sdkResults[RESPONSE_TIMES], completionTime);
    orderedInsert(sdkResults[RESULT_COUNTS], resultCount);
    sdkResults[TOTAL] += completionTime;
    sdkResults[MIN] = _min(sdkResults[MIN], completionTime);
    sdkResults[MAX] = _max(sdkResults[MAX], completionTime);
    updateCalculations(sdkResults);
  } else {
    ++sdkResults[INCOMPLETE];
  }
  return results;
};

/// Merge two sets of results
final completionReductionMerge = (Map results1, Map results2) {
  Map newResults = {};
  results1.forEach((key, sdkResults1) {
    var sdkResults2 = results2[key];
    if (sdkResults2 == null) {
      newResults[key] = sdkResults1;
    } else {
      var total = sdkResults1[TOTAL] + sdkResults2[TOTAL];
      var values = []..addAll(sdkResults1[RESPONSE_TIMES]);
      for (int completionTime in sdkResults2[RESPONSE_TIMES]) {
        orderedInsert(values, completionTime);
      }
      var counts = []..addAll(sdkResults1[RESULT_COUNTS]);
      for (int resultCount in sdkResults2[RESULT_COUNTS]) {
        orderedInsert(counts, resultCount);
      }
      var sdkResults = {
        VERSION: key,
        RESPONSE_TIMES: values,
        RESULT_COUNTS: counts,
        TOTAL: total,
        MIN: _min(sdkResults1[MIN], sdkResults2[MIN]),
        MAX: _max(sdkResults1[MAX], sdkResults2[MAX]),
        INCOMPLETE: sdkResults1[INCOMPLETE] + sdkResults2[INCOMPLETE]
      };
      updateCalculations(sdkResults);
      newResults[key] = sdkResults;
    }
  });
  results2.forEach((key, sdkResults2) {
    var sdkResults1 = results1[key];
    if (sdkResults1 == null) {
      newResults[key] = sdkResults2;
    }
  });
  return newResults;
};

/// Update the calculated values in the SDK results map
void updateCalculations(sdkResults) {
  List<int> values = sdkResults[RESPONSE_TIMES];
  sdkResults[AVE] = sdkResults[TOTAL] / values.length;
  sdkResults[V90TH] = values[(values.length * (9 / 10)).floor()];
  sdkResults[V99TH] = values[(values.length * (99 / 100)).floor()];
  sdkResults[RESPONSE_TIME_BUCKETS] = _gatherIntoBuckets(values, [32]);
  var counts = sdkResults[RESULT_COUNTS];
  sdkResults[RESULT_COUNT_BUCKETS] = _gatherIntoBuckets(counts, [0, 1, 5, 50]);
}

/// Return a allocation map generated from the given [sortedValues]
/// where [limits] are the bounds used for the initial set of buckets.
/// Any values beyond the last bound specified in [limits]
/// are placed into buckets of size increasing by a multiple of 2
/// times the last bucket bounds.
Map<int, int> _gatherIntoBuckets(List<int> sortedValues, List<int> limits) {
  var limitIter = limits.iterator..moveNext();
  int limit = limitIter.current;
  Map<int, int> clusters = {};
  int lastIndex = 0;
  for (int index = 0; index < sortedValues.length; ++index) {
    while (limit < sortedValues[index]) {
      var count = index - lastIndex;
      clusters[limit] = count;
      limit = limitIter.moveNext() ? limitIter.current : limit * 2;
      lastIndex = index;
    }
  }
  var count = sortedValues.length - lastIndex;
  clusters[limit] = count;
  return clusters;
}

int _max(int value1, int value2) {
  if (value1 == null) return value2;
  if (value2 == null) return value1;
  return value1 > value2 ? value1 : value2;
}

int _min(int value1, int value2) {
  if (value1 == null) return value2;
  if (value2 == null) return value1;
  return value1 < value2 ? value1 : value2;
}

/// [CompletionMapper] processes session log messages and extracts
/// metrics for each call to code completion
class CompletionMapper extends InstrumentationMapper {
  /// A mapping of completion notification ID to information abou the completion.
  /// Elements are added when a completion response is found
  /// and removed when the final notification is found.
  Map<String, _Completion> _notificationMap = <String, _Completion>{};

  /// A mapping of request ID to information about the completion request.
  /// Elements are added when a request is found
  /// and removed when a matching reponse is found
  Map<String, _Completion> _requestMap = <String, _Completion>{};

  /// Reporting any partial completion information
  @override
  void cleanup() {
    for (_Completion _ in _requestMap.values) {
      // TODO (danrubel) provide better message for incomplete requests
      addResult(sdkVersion, _composeResult(-1, 0));
    }
    _requestMap.clear();
    for (_Completion _ in _notificationMap.values) {
      // TODO (danrubel) provide better message for missing notifications
      addResult(sdkVersion, _composeResult(-2, 0));
    }
    _notificationMap.clear();
  }

  @override
  void mapLogMessage(int time, String msgType, String logMessageText) {
    if (msgType == 'Req') {
      String method = extractJsonValue(logMessageText, 'method');
      _processRequest(time, method, logMessageText);
    } else if (msgType == 'Res') {
      String requestId = extractJsonValue(logMessageText, 'id');
      _processResponse(time, requestId, logMessageText);
    } else if (msgType == 'Noti') {
      String event = extractJsonValue(logMessageText, 'event');
      _processNotification(time, event, logMessageText);
    } else if (msgType == 'Read') {
      // process read entry
    } else if (msgType == 'Task') {
      // process task entry
    } else if (msgType == 'Log') {
      // process log entry
    } else if (msgType == 'Perf') {
      // process perf entry
    } else if (msgType == 'Watch') {
      // process watch entry
    }
    //throw 'unknown msgType $msgType in $logMessageText';
  }

  /// Return an extraction result, which is a list containing
  ///
  /// * completionTime - the number of milliseconds from request
  ///     until completions are provided to the client
  /// * resultCount - the number of suggestions provided
  ///
  _composeResult(int responseTimeMs, int resultCount) =>
      [responseTimeMs, resultCount];

  /// Process a log entry representing a notification
  void _processNotification(int time, String event, String logMessageText) {
    if (event == 'completion.results') {
      if (!logMessageText.endsWith(',"isLast"::true}}')) return null;
      Map json = JSON.decode(logMessageText.replaceAll("::", ":"));
      Map params = json['params'];
      String notificationId = params['id'];
      _Completion completion = _notificationMap.remove(notificationId);
      if (completion == null) {
        throw 'expected completion request for ${trim300(logMessageText)}';
      }
      List results = params['results'];
      var responseTimeMs = time - completion.requestTime;
      var resultCount = results.length;
      addResult(sdkVersion, _composeResult(responseTimeMs, resultCount));
    }
    return null;
  }

  /// Process a log entry representing a request
  void _processRequest(int time, String method, String logMessageText) {
    // Look for completion requests
    if (method == 'completion.getSuggestions') {
      String requestId = extractJsonValue(logMessageText, 'id');
      _requestMap[requestId] = new _Completion(time);
    }
  }

  /// Process a log entry representing a response
  void _processResponse(int time, String requestId, String logMessageText) {
    _Completion completion = _requestMap.remove(requestId);
    if (completion != null) {
      String result = extractJsonValue(logMessageText, 'result');
      String notificationId = extractJsonValue(result, 'id');
      _notificationMap[notificationId] = completion;
      completion.responseTime = time;
    }
  }
}

/// Information about a completion request / response / notification group
class _Completion {
  int requestTime;
  int responseTime;
  _Completion(this.requestTime);
}
