// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.query.perf;

import 'dart:convert';

import 'package:sintr_worker_lib/instrumentation_query.dart';

const ANALYSIS_PERF = 'Analysis';
const INTERNAL_PERF = 'Internal';
const REQUEST_PERF = 'Request';

/// Add an extraction result to the overall API usage [results]
/// where [extracted] is provided by [PerfMapper].
final apiUsageReducer = (String sdkVersion, List perfData, Map results) {
  // Extract perf data
  var perfType = perfData[2];
  var perfName = perfData[3];

  // Record number of requests of each type per SDK
  if (perfType == REQUEST_PERF) {
    Map sdkResults = results.putIfAbsent(sdkVersion, () => {});
    sdkResults.putIfAbsent(perfName, () => 0);
    ++sdkResults[perfName];
  }

  return results;
};

/// Merge two sets of results
final apiUsageReductionMerge = mergeBucketsRecursively;

/// Add an extraction result to the overall performance [results]
/// where [extracted] is provided by [PerfMapper].
final perfReducer = (String sdkVersion, List perfData, Map results) {
  // Extract perf data
  var perfType = perfData[2];
  var perfName = perfData[3];
  var elapsedTime = perfData[4];

  // Sanity check
  if (elapsedTime is! int) return results;

  // Extract current results
  Map sdkResults = results.putIfAbsent(sdkVersion, () => {});
  Map perfTypeResults = sdkResults.putIfAbsent(perfType, () => {});
  Map perfResults = perfTypeResults.putIfAbsent(perfName, () => {});

  // Update current results
  updateBucket(perfResults, elapsedTime);
  return results;
};

/// Merge two sets of results
final perfReductionMerge = mergeBucketsRecursively;

/// [PerfMapper] processes session messages and extracts 'Perf' entries
/// along with request/response pair performance.
/// Results keys are [sdkVersion] and values are a list containing
///
/// * [sessionId]
/// * time
/// * perfType (one of INTERNAL_PERF, REQUEST_RESPONSE_PERF, ...)
/// * perfName or request API method
/// * elapse time milliseconds reported by 'Perf'
///     or elapse time milliseconds between request/response
/// * ... additional perf data if any ...
///
class PerfMapper extends InstrumentationMapper {
  /// A map of request id to [Request]
  Map<String, Request> requestMap = {};

  /// The number of responses for which requests were not found
  var missingRequestCount = 0;

  /// The time at which analysis was first requested...
  ///   `analysis.setAnalysisRoots` or `analysis.reanalyze`
  int analysisStartTime;

  /// The time at which pub list is called.
  int pubListStartTime;

  @override
  void mapLogMessage(int time, String msgType, String logMessageText) {
    if (msgType == 'Perf') {
      _processPerf(time, logMessageText);
    } else if (msgType == 'Req') {
      String method = extractJsonValue(logMessageText, 'method');
      _processRequest(time, method, logMessageText);
    } else if (msgType == 'Res') {
      String requestId = extractJsonValue(logMessageText, 'id');
      _processResponse(time, requestId, logMessageText);
    } else if (msgType == 'Noti') {
      String event = extractJsonValue(logMessageText, 'event');
      _processNotification(time, event, logMessageText);
    }
  }

  void _processNotification(int time, String event, String logMessageText) {
    // {"event"::"server.status","params":: .....
    if (event == 'server.status') {
      if (analysisStartTime != null) {
        var json = JSON.decode(logMessageText.replaceAll('::', ':'));
        var params = json['params'];
        if (params != null) {
          // "params"::{"analysis"::{"isAnalyzing"::false}}
          var analysis = params['analysis'];
          if (analysis != null) {
            if (analysisStartTime != null) {
              var isAnalyzing = analysis['isAnalyzing'];
              if (isAnalyzing == false) {
                var elapsedTimeMs = time - analysisStartTime;
                addResult(sdkVersion, [
                  sessionId,
                  time,
                  ANALYSIS_PERF,
                  'complete',
                  elapsedTimeMs
                ]);
                analysisStartTime = null;
              }
            }
          }

          // "params"::{"pub"::{"isListingPackageDirs"::true}}
          var pub = params['pub'];
          if (pub != null) {
            var isListingPackageDirs = pub['isListingPackageDirs'];
            if (isListingPackageDirs == true) {
              pubListStartTime = time;
            }
            if (isListingPackageDirs == false && pubListStartTime != null) {
              var elapsedTimeMs = time - pubListStartTime;
              addResult(sdkVersion,
                  [sessionId, time, ANALYSIS_PERF, 'pubList', elapsedTimeMs]);
              pubListStartTime = null;
            }
          }
        }
      }
    }
  }

  void _processPerf(int time, String logMessageText) {
    // ~1428628074716:Perf:analysis_full:607:context_id=3
    var perfData = [sessionId, time, INTERNAL_PERF]
      ..addAll(logMessageText.split(':'));
    try {
      perfData[4] = int.parse(perfData[4]);
    } catch (e) {
      // ignored
    }
    addResult(sdkVersion, perfData);
  }

  void _processRequest(int time, String method, String logMessageText) {
    // ~1422652636123:Req:{"id"::"89","method"::"completion.getSuggestions" ...
    var id = extractJsonValue(logMessageText, 'id');
    requestMap[id] = new Request(time, id, method);
    if (method == 'analysis.reanalyze' ||
        method == 'analysis.setAnalysisRoots') {
      analysisStartTime = time;
    }
  }

  void _processResponse(int time, String requestId, String logMessageText) {
    // ~1422652636123:Res:{"id"::"89","result"::{"id"::"11"}}
    var id = extractJsonValue(logMessageText, 'id');
    var request = requestMap.remove(id);
    if (request == null) {
      ++missingRequestCount;
    } else {
      var elapsedTimeMs = time - request.time;
      addResult(sdkVersion,
          [sessionId, time, REQUEST_PERF, request.method, elapsedTimeMs]);
    }
  }
}

class Request {
  final int time;
  final String id;
  final String method;
  Request(this.time, this.id, this.method);
}
