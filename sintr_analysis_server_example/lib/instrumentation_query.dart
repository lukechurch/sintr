// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.instrumentation_query;

import 'dart:async';

import 'package:sintr_worker_lib/query.dart';
import 'package:sintr_worker_lib/session_info.dart';

const _DEBUG = true;

final OPEN_BRACE = '{'.codeUnitAt(0);
final QUOTE = '"'.codeUnitAt(0);

/// Search the given [logMessageText] for the given [key]
/// and return the associated value.
/// This only returns simple values such as strings
/// non-nested maps.
String extractJsonValue(String logMessageText, String key) {
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
    if (end == -1) {
      throw 'expected matching brace for $key in $logMessageText';
    }
    return logMessageText.substring(start, end + 1);
  }
  // TODO (danrubel) handled ints and lists
  return null;
}

/// Insert [newValue] into the sorted list of [sortedValues]
/// such that the list is still sorted.
void orderedInsert(List sortedValues, var newValue, [int comparator(v1, v2)]) {
  if (comparator == null) comparator = (v1, v2) => v1 - v2;
  if (_DEBUG) verifySorted(sortedValues, comparator);
  if (sortedValues.length == 0) {
    sortedValues.add(newValue);
    return;
  }
  if (comparator(newValue, sortedValues[0]) < 0) {
    sortedValues.insert(0, newValue);
    if (_DEBUG) verifySorted(sortedValues, comparator);
    return;
  }
  int start = 0;
  int end = sortedValues.length;
  int pivot = start + (end - start) ~/ 2;
  while (end - start > 1 || sortedValues[pivot] == newValue) {
    var diff = comparator(newValue, sortedValues[pivot]);
    if (diff == 0) break;
    if (diff > 0) {
      start = pivot;
    } else {
      end = pivot;
    }
    pivot = start + (end - start) ~/ 2;
  }
  sortedValues.insert(pivot + 1, newValue);
  if (_DEBUG) verifySorted(sortedValues, comparator);
}

/// Verify that the given [values] are sorted.
/// The default [comparator] compares two number.
void verifySorted(List<int> values, [int comparator(v1, v2)]) {
  if (comparator == null) comparator = (v1, v2) => v1 - v2;
  for (int index = 1; index < values.length; ++index) {
    if (comparator(values[index - 1], values[index]) > 0) {
      throw 'Unsorted value at values[$index]:'
          ' ${values[index - 1]}, ${values[index]}\n  $values';
    }
  }
}

/// [Mapper] is the base interface used by worker isolates to extract results
/// from a given target.
///
/// * [#init] is called once with the extraction target
/// * [#map] is called once for each message in the extraction target
/// * [#cleanup] is called once after processing is complete
///
abstract class InstrumentationMapper extends Mapper {
  /// The SDK version for the session being processed.
  String sdkVersion = 'unset';

  /// The session identifier for the session being processed.
  String sessionId = 'unset';

  /// Initialize the completion extraction process.
  @override
  Future init(Map<String, dynamic> sessionInfo, AddResult addResult) async {
    super.init(sessionInfo, addResult);
    sdkVersion = sessionInfo[SDK_VERSION] ?? 'unknown';
    sessionId = sessionInfo[SESSION_ID] ?? 'unknown';
  }

  /// Process a log message and call [addResult] with any results
  /// extracted from the given log entry.
  @override
  void map(String logEntryText) {
    if (isMapStopped) return;
    if (logEntryText == null || logEntryText == "") return;
    if (!logEntryText.startsWith("~")) return;

    int index1 = logEntryText.indexOf(':', 1);
    if (index1 == -1) return;
    int time = int.parse(logEntryText.substring(1, index1));

    int index2 = logEntryText.indexOf(':', index1 + 1);
    if (index2 == -1) return;
    String msgType = logEntryText.substring(index1 + 1, index2);

    String message = logEntryText.substring(index2 + 1);
    mapLogMessage(time, msgType, message);
  }

  /// Process a log message and call [addResult] with any results
  /// extracted from the given log entry.
  void mapLogMessage(int time, String msgType, String logMessageText);
}
