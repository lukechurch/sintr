library sintr_worker_lib.completion;

import 'dart:async';
import 'dart:math' as math;

import 'package:sintr_worker_lib/query.dart';
import 'package:sintr_worker_lib/session_info.dart';

const AVE = 'ave';
const COUNT = 'count';
const INCOMPLETE = 'incomplete';
const MAX = 'max';
const MIN = 'min';
const TOTAL = 'total';
const VERSION = 'version';

/// Process log line that was encoded by [_composeExtractionResult]
/// and return a map of current results
final completionReducer = (String sdkVersion, int completionTime, Map results) {

  // Extract current results for SDK
  // version, min, ave, max, count, total, incomplete
  var sdkResults = results[sdkVersion];
  if (sdkResults == null) {
    sdkResults = {
      VERSION: sdkVersion,
      COUNT: 0,
      TOTAL: 0,
      MIN: 0,
      AVE: 0,
      MAX: 0,
      INCOMPLETE: 0
    };
    results[sdkVersion] = sdkResults;
  }

  // Update results with new information
  if (completionTime > 0) {
    ++sdkResults[COUNT];
    sdkResults[TOTAL] += completionTime;
    sdkResults[MIN] = math.min(sdkResults[MIN], completionTime);
    sdkResults[AVE] = sdkResults[TOTAL] / sdkResults[COUNT];
    sdkResults[MAX] = math.max(sdkResults[MAX], completionTime);
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
      var count = sdkResults1[COUNT] + sdkResults2[COUNT];
      var total = sdkResults1[TOTAL] + sdkResults2[TOTAL];
      var sdkResults = {
        VERSION: key,
        COUNT: count,
        TOTAL: total,
        MIN: math.min(sdkResults1[MIN], sdkResults2[MIN]),
        AVE: total / count,
        MAX: math.max(sdkResults1[MAX], sdkResults2[MAX]),
        INCOMPLETE: sdkResults1[INCOMPLETE] + sdkResults2[INCOMPLETE]
      };
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

final OPEN_BRACE = '{'.codeUnitAt(0);
final QUOTE = '"'.codeUnitAt(0);

/// [CompletionMapper] processes session log messages and extracts
/// metrics for each call to code completion
class CompletionMapper extends Mapper {
  /// A mapping of completion notification ID to information abou the completion.
  /// Elements are added when a completion response is found
  /// and removed when the final notification is found.
  Map<String, _Completion> _notificationMap = <String, _Completion>{};

  /// A mapping of request ID to information about the completion request.
  /// Elements are added when a request is found
  /// and removed when a matching reponse is found
  Map<String, _Completion> _requestMap = <String, _Completion>{};

  /// The SDK version
  String _sdkVersion = 'unset';

  /// Reporting any partial completion information
  @override
  void cleanup() {
    for (_Completion completion in _requestMap.values) {
      // TODO (danrubel) provide better message for incomplete requests
      addResult(_sdkVersion, -1);
    }
    _requestMap.clear();
    for (_Completion completion in _notificationMap.values) {
      // TODO (danrubel) provide better message for missing notifications
      addResult(_sdkVersion, -2);
    }
    _notificationMap.clear();
  }

  /// Initialize the completion extraction process
  @override
  Future init(Map<String, dynamic> sessionInfo, AddResult addResult) async {
    super.init(sessionInfo, addResult);
    _sdkVersion = sessionInfo[SDK_VERSION] ?? 'unknown';
  }

  /// Process a log entry and return a string representing the result
  /// or `null` if no result from the given log entry.
  @override
  void map(String logEntryText) {
    if (logEntryText == null || logEntryText == "") return null;
    if (!logEntryText.startsWith("~")) return null;

    int index1 = logEntryText.indexOf(':', 1);
    if (index1 == -1) return null;
    int time = int.parse(logEntryText.substring(1, index1));

    int index2 = logEntryText.indexOf(':', index1 + 1);
    if (index2 == -1) return null;
    String msgType = logEntryText.substring(index1 + 1, index2);

    String message = logEntryText.substring(index2 + 1);
    _processLogMessage(time, msgType, message);
  }

  /// Search the given [logMessageText] for the given [key]
  /// and return the associated value.
  String _extractJsonValue(String logMessageText, String key) {
    var prefix = '"$key"::';
    int start = logMessageText.indexOf(prefix);
    if (start == -1) throw 'expected $key in $logMessageText';
    start += prefix.length;
    int deliminator = logMessageText.codeUnitAt(start);
    if (deliminator == QUOTE) {
      // Return quoted string
      ++start;
      int end = logMessageText.indexOf('"', start);
      if (end == -1) throw 'expected value for $key in $logMessageText';
      return logMessageText.substring(start, end);
    } else if (deliminator == OPEN_BRACE) {
      // Return JSON map
      // TODO (danrubel) handle nested and embedded braces
      int end = logMessageText.indexOf('}');
      if (end ==
          -1) throw 'expected matching brace for $key in $logMessageText';
      return logMessageText.substring(start, end + 1);
    }
    return null;
  }

  /// Process a log message and return a string representing the result
  /// or `null` if no result from the given log entry.
  void _processLogMessage(int time, String msgType, String logMessageText) {
    if (msgType == 'Req') {
      String method = _extractJsonValue(logMessageText, 'method');
      _processRequest(time, method, logMessageText);
    } else if (msgType == 'Res') {
      String requestId = _extractJsonValue(logMessageText, 'id');
      _processResponse(time, requestId, logMessageText);
    } else if (msgType == 'Noti') {
      String event = _extractJsonValue(logMessageText, 'event');
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

  /// Process a log entry representing a notification
  void _processNotification(int time, String event, String logMessageText) {
    if (event == 'completion.results') {
      if (!logMessageText.endsWith(',"isLast"::true}}')) return null;
      var prefix = '{"event"::"completion.results","params"::{"id"::"';
      if (!logMessageText.startsWith(prefix)) {
        throw 'expected $prefix in $logMessageText';
      }
      int start = prefix.length;
      int end = logMessageText.indexOf('"', start);
      if (end == -1) throw 'expected notification id in $logMessageText';
      String notificationId = logMessageText.substring(start, end);
      _Completion completion = _notificationMap.remove(notificationId);
      if (completion == null) {
        throw 'expected completion request for $logMessageText';
      }
      addResult(_sdkVersion, time - completion.requestTime);
    }
    return null;
  }

  /// Process a log entry representing a request
  void _processRequest(int time, String method, String logMessageText) {
    // Look for completion requests
    if (method == 'completion.getSuggestions') {
      String requestId = _extractJsonValue(logMessageText, 'id');
      _requestMap[requestId] = new _Completion(time);
    }
  }

  /// Process a log entry representing a response
  void _processResponse(int time, String requestId, String logMessageText) {
    _Completion completion = _requestMap.remove(requestId);
    if (completion != null) {
      String result = _extractJsonValue(logMessageText, 'result');
      String notificationId = _extractJsonValue(result, 'id');
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
