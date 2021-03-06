// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.instrumentation_query;

import 'dart:async';

import 'query.dart';
import 'session_info.dart';

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

/// Merge two result maps containing only numeric values
/// where values for equal keys are added in the final result.
Map mergeBucketsRecursively(Map results1, Map results2) {
  Map results = {};
  results1.forEach((key, value1) {
    var value2 = results2[key];
    if (value2 == null) {
      results[key] = value1;
    } else if (value1 is Map) {
      results[key] = mergeBucketsRecursively(value1, value2);
    } else {
      results[key] = value1 + value2;
    }
  });
  results2.forEach((key, value2) {
    var value1 = results1[key];
    if (value1 == null) {
      results[key] = value2;
    }
  });
  return results;
}

/// Insert [newValue] into the sorted list of [sortedValues]
/// such that the list is still sorted.
void orderedInsert/*<T>*/(List/*<T>*/ sortedValues, var/*=T*/ newValue,
    [int comparator(/*=T*/ v1, /*=T*/ v2)]) {
  if (comparator == null)
    comparator = (Comparable v1, Comparable v2) => v1.compareTo(v2);
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
    int diff = comparator(newValue, sortedValues[pivot]);
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

/// Increment the count in the bucket containing [value]
/// where [limits] are the bounds used for the initial set of buckets.
/// Any values beyond the last bound specified in [limits]
/// are placed into buckets of size increasing by a multiple of 2
/// times the last bucket bounds.
void updateBucket(Map<int, int> buckets, int value,
    {List<int> limits: const [0, 1, 5, 25, 50]}) {
  var limitIter = limits.iterator..moveNext();
  int limit = limitIter.current;
  while (limit < value) {
    buckets.putIfAbsent(limit, () => 0);
    limit = limitIter.moveNext() ? limitIter.current : limit * 2;
  }
  buckets.putIfAbsent(limit, () => 0);
  ++buckets[limit];
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

  /// The number of processed log entries
  int logEntryCount = 0;

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
    if (logEntryCount == 1000 * 1000 * 1000) isMapStopped = true;
    ++logEntryCount;
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
