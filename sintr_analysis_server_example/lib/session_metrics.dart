// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.session_metrics;

import 'dart:convert';

/// Initialize the session info extraction process
final sessionInfoExtractionStart = (Map sessionInfo) {
  _sessionId = sessionInfo['sessionId'] ?? 'unknown';
};

/// Process a log entry and return a string representing the result
/// or `null` if no result from the given log entry.
final sessionInfoExtraction = (String logEntryText) {
  if (logEntryText == null || logEntryText == "") return null;
  if (!logEntryText.startsWith("~")) return null;

  int index1 = logEntryText.indexOf(':', 1);
  if (index1 == -1) return null;
  int time = int.parse(logEntryText.substring(1, index1));

  int index2 = logEntryText.indexOf(':', index1 + 1);
  if (index2 == -1) return null;
  String msgType = logEntryText.substring(index1 + 1, index2);

  if (msgType == 'Ver') {
    var data = logEntryText.split(':');
    return JSON.encode({
      'sessionId': _sessionId,
      'clientStartTime': data[0].substring(1),
      'uuid': data[2],
      'clientId': data[3],
      'clientVersion': data[4],
      'serverVersion': data[5],
      'sdkVersion': data[6]
    });
  }
  //throw 'unknown msgType $msgType in $logMessageText';
  return null;
};

final sessionInfoExtractionFinished = () => null;

/// Process log line
/// and return a map of current results
final sessionInfoReducer = (String extractionResult, Map results) {
  Map sessionInfo = JSON.decode(extractionResult);

  // Extract session information
  var clientStartTime = int.parse(sessionInfo['clientStartTime']);
  String clientStartDate =
      new DateTime.fromMillisecondsSinceEpoch(clientStartTime)
          .toIso8601String()
          .substring(0, 10); // yyyy-MM-dd
  String sdkVersion = sessionInfo['sdkVersion'];

  // Extract current results for date
  Map dateResults = results.putIfAbsent(clientStartDate, () => {});

  // Update SDK count
  dateResults[sdkVersion] = (dateResults[sdkVersion] ?? 0) + 1;

  return results;
};

/// Merge two sets of results
final sessionInfoReductionMerge = (Map results1, Map results2) {
  Map newResults = {};
  results1.forEach((date, Map dateResults1) {
    Map dateResults2 = results2[date];
    if (dateResults2 == null) {
      newResults[date] = dateResults1;
    } else {
      Map dateResults = {};
      dateResults1.forEach((sdkVersion, count){
        dateResults[sdkVersion] = count + (dateResults2[sdkVersion] ?? 0);
      });
      dateResults2.forEach((sdkVersion, count) {
        dateResults.putIfAbsent(sdkVersion, () => count);
      });
      newResults[date] = dateResults;
    }
  });
  results2.forEach((date, sdkResults2) {
    var sdkResults1 = results1[date];
    if (sdkResults1 == null) {
      newResults[date] = sdkResults2;
    }
  });
  return newResults;
};

/// The session ID
var _sessionId = 'unset';
