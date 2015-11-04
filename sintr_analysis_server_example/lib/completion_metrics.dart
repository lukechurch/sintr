library sintr_worker_lib.completion;

import 'dart:math' as math;

/// Initialize the completion extraction process
final completionExtractionStart = (Map sessionInfo) {
  _sdkVersion = sessionInfo['sdkVersion'] ?? 'unknown';
};

/// Process a log entry and return a string representing the result
/// or `null` if no result from the given log entry.
final completionExtraction = (String logEntryText) {
  if (logEntryText == null || logEntryText == "") return null;
  if (!logEntryText.startsWith("~")) return null;

  int index1 = logEntryText.indexOf(':', 1);
  if (index1 == -1) return null;
  int time = int.parse(logEntryText.substring(1, index1));

  int index2 = logEntryText.indexOf(':', index1 + 1);
  if (index2 == -1) return null;
  String msgType = logEntryText.substring(index1 + 1, index2);

  return _processLogMessage(time, msgType, logEntryText.substring(index2 + 1));
};

/// Reporting any partial completion information
final completionExtractionFinished = () {
  var results = [];
  for (_Completion completion in _requestMap.values) {
    results.add(_composeExtractionResult(completion, -1));
  }
  _requestMap.clear();
  for (_Completion completion in _notificationMap.values) {
    results.add(_composeExtractionResult(completion, -2));
  }
  _notificationMap.clear();
  return results;
};

/// Process log line that was encoded by [_composeExtractionResult]
/// and return a map of current results
final completionReducer = (String extractionResult, Map results) {
  // Extract completion information
  var split = extractionResult.split(',');
  var sdkVersion = split[0];
  var completionTime = int.parse(split[1]);

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

final AVE = 'ave';
final COUNT = 'count';
final INCOMPLETE = 'incomplete';
final MAX = 'max';
final MIN = 'min';
final OPEN_BRACE = '{'.codeUnitAt(0);
final QUOTE = '"'.codeUnitAt(0);
final TOTAL = 'total';
final VERSION = 'version';

/// The SDK version
String _sdkVersion = 'unset';

/// A mapping of completion notification ID to information abou the completion.
/// Elements are added when a completion response is found
/// and removed when the final notification is found.
Map<String, _Completion> _notificationMap = <String, _Completion>{};

/// A mapping of request ID to information about the completion request.
/// Elements are added when a request is found
/// and removed when a matching reponse is found
Map<String, _Completion> _requestMap = <String, _Completion>{};

String _composeExtractionResult(_Completion completion, int completionTime) =>
    '$_sdkVersion,$completionTime';

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
    if (end == -1) throw 'expected matching brace for $key in $logMessageText';
    return logMessageText.substring(start, end + 1);
  }
  return null;
}

/// Process a log message and return a string representing the result
/// or `null` if no result from the given log entry.
String _processLogMessage(int time, String msgType, String logMessageText) {
  if (msgType == 'Req') {
    String method = _extractJsonValue(logMessageText, 'method');
    return _processRequest(time, method, logMessageText);
  } else if (msgType == 'Res') {
    String requestId = _extractJsonValue(logMessageText, 'id');
    return _processResponse(time, requestId, logMessageText);
  } else if (msgType == 'Noti') {
    String event = _extractJsonValue(logMessageText, 'event');
    return _processNotification(time, event, logMessageText);
  } else if (msgType == 'Read') {
    return null;
  } else if (msgType == 'Task') {
    return null;
  } else if (msgType == 'Log') {
    return null;
  } else if (msgType == 'Perf') {
    return null;
  } else if (msgType == 'Watch') {
    return null;
  }
  //throw 'unknown msgType $msgType in $logMessageText';
  return null;
}

/// Process a log entry representing a notification
String _processNotification(int time, String event, String logMessageText) {
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
    return _composeExtractionResult(completion, time - completion.requestTime);
  }
  return null;
}

/// Process a log entry representing a request
String _processRequest(int time, String method, String logMessageText) {
  // Look for completion requests
  if (method == 'completion.getSuggestions') {
    String requestId = _extractJsonValue(logMessageText, 'id');
    _requestMap[requestId] = new _Completion(time);
  }
  return null;
}

/// Process a log entry representing a response
String _processResponse(int time, String requestId, String logMessageText) {
  _Completion completion = _requestMap.remove(requestId);
  if (completion != null) {
    String result = _extractJsonValue(logMessageText, 'result');
    String notificationId = _extractJsonValue(result, 'id');
    _notificationMap[notificationId] = completion;
    completion.responseTime = time;
  }
  return null;
}

/// Information about a completion request / response / notification group
class _Completion {
  int requestTime;
  int responseTime;
  _Completion(this.requestTime);
}
