// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.completion.test;

import 'package:sintr_worker_lib/instrumentation_query.dart';
import 'package:sintr_worker_lib/query/completion_metrics.dart';
import 'package:test/test.dart';

main() {
  test('completionReducer', () {
    Map<String, Map<String, dynamic>> results = {};

    results = completionReducer('sdk1', [24, 99], results);
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 24, 24, 24, 24, 24, 24, 0);

    results = completionReducer('sdk1', [12, 99], results);
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 12, 24, 18, 24, 24, 24, 0);

    var newValues = [];
    for (int count = 2; count <= 100; ++count) {
      newValues.add(100 + count);
    }
    newValues.shuffle();
    newValues.forEach((value) {
      results = completionReducer('sdk1', [value, 99], results);
    });
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 12, 200, 148, 190, 195, 199, 0);

    newValues.shuffle();
    newValues.forEach((value) {
      results = completionReducer('sdk1', [value, 99], results);
    });
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 12, 200, 150, 191, 196,  200, 0);

    results = completionReducer('sdk1', [-1, 0], results);
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 12, 200, 150, 191, 196, 200, 1);

    results = completionReducer('sdk2', [27, 99], results);
    expect(results, hasLength(2));
    _expectSdkResults(results['sdk1'], 12, 200, 150, 191, 196, 200, 1);
    _expectSdkResults(results['sdk2'], 27, 27, 27, 27, 27, 27, 0);
  });

  test('completionReductionMerge', () {
    Map<String, Map<String, dynamic>> results1 = {};

    results1 = _merge(results1, 'sdk1', 12);
    expect(results1, hasLength(1));
    _expectSdkResults(results1['sdk1'], 12, 12, 12, 12, 12, 12, 0);

    results1 = _merge(results1, 'sdk1', 24);
    expect(results1, hasLength(1));
    _expectSdkResults(results1['sdk1'], 12, 24, 18, 24, 24, 24, 0);

    results1 = _merge(results1, 'sdk1', -1);
    expect(results1, hasLength(1));
    _expectSdkResults(results1['sdk1'], 12, 24, 18, 24, 24, 24, 1);

    results1 = _merge(results1, 'sdk1', -2);
    expect(results1, hasLength(1));
    _expectSdkResults(results1['sdk1'], 12, 24, 18, 24, 24, 24, 2);

    results1 = _merge(results1, 'sdk2', 27);
    expect(results1, hasLength(2));
    _expectSdkResults(results1['sdk1'], 12, 24, 18, 24, 24, 24, 2);
    _expectSdkResults(results1['sdk2'], 27, 27, 27, 27, 27, 27, 0);

    Map<String, Map<String, dynamic>> results2 = {};

    var newValues = [];
    for (int count = 2; count <= 100; ++count) {
      newValues.add(100 + count);
    }
    newValues.shuffle();
    newValues.forEach((value) {
      results2 = _merge(results2, 'sdk1', value);
    });
    expect(results2, hasLength(1));
    _expectSdkResults(results2['sdk1'], 102, 200, 151, 191, 196, 200, 0);

    results2 = _merge(results2, 'sdk1', -2);
    expect(results2, hasLength(1));
    _expectSdkResults(results2['sdk1'], 102, 200, 151, 191, 196, 200, 1);

    results2 = _merge(results2, 'sdk3', 82);
    expect(results2, hasLength(2));
    _expectSdkResults(results2['sdk1'], 102, 200, 151, 191, 196, 200, 1);
    _expectSdkResults(results2['sdk3'], 82, 82, 82, 82, 82, 82, 0);

    var results = completionReductionMerge(results1, results2);
    expect(results, hasLength(3));
    _expectSdkResults(results['sdk1'], 12, 200, 148, 190, 195, 199, 3);
    _expectSdkResults(results['sdk2'], 27, 27, 27, 27, 27, 27, 0);
    _expectSdkResults(results['sdk3'], 82, 82, 82, 82, 82, 82, 0);
  });

  test('updateCalculations', () {
    var sdkResults = {
      VERSION: '1.10.0-dev.0.0-hotfix1+1',
      RESPONSE_TIMES: [
        1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3,
        3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
        3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
        3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6,
        6, 6, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 8,
        8, 8, 9, 9, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 11, 11, 11, 12,
        12, 13, 14, 14, 15, 15, 15, 16, 16, 16, 17, 18, 18, 18, 18, 18, 19,
        19, 19, 20, 20, 20, 21, 21, 21, 22, 22, 22, 23, 24, 25, 25, 26, 27,
        27, 27, 27, 30, 31, 33, 33, 34, 36, 36, 36, 37, 37, 37, 38, 38, 40,
        41, 42, 42, 43, 44, 48, 52, 56, 60, 72, 87, 285, 289, 290, 306, 312,
        336, 343, 347, 347, 350, 351, 368, 372, 375, 380, 382, 384, 387, 389,
        393, 397, 397, 407, 413, 420, 505, 509, 560, 618, 694, 738, 770],
      RESULT_COUNTS: [
        0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 4, 6, 7, 9, 10, 12, 14, 16, 50, 80, 100],
      TOTAL: 16115,
      MIN: 1,
      MAX: 770,
      INCOMPLETE: 13,
    };
    updateCalculations(sdkResults);
    expect(sdkResults[AVE].round(), 54);
    expect(sdkResults[V90TH], 290);
    expect(sdkResults[V99TH], 694);
    Map<int, int> values = sdkResults[RESPONSE_TIME_BUCKETS];
    expect(values, hasLength(6));
    expect(values[32], 241);
    expect(values[64], 21);
    expect(values[128], 2);
    expect(values[256], 0);
    expect(values[512], 27);
    expect(values[1024], 5);
    Map<int, int> counts = sdkResults[RESULT_COUNT_BUCKETS];
    expect(counts, hasLength(5));
    expect(counts[0], 4);
    expect(counts[1], 6);
    expect(counts[5], 1);
    expect(counts[50], 8);
    expect(counts[100], 2);
  });
}

void _expectSdkResults(Map<String, dynamic> sdkResults, int min, int max,
    int ave, int v90th, int v95th, int v99th, int incomplete) {
  verifySorted(sdkResults[RESPONSE_TIMES]);
  verifySorted(sdkResults[RESULT_COUNTS]);
  expect(sdkResults[RESPONSE_TIMES].length, sdkResults[RESULT_COUNTS].length);
  expect(sdkResults[MIN], min);
  expect(sdkResults[MAX], max);
  expect(sdkResults[AVE].round(), ave);
  expect(sdkResults[V90TH], v90th);
  expect(sdkResults[V95TH], v95th);
  expect(sdkResults[V99TH], v99th);
  expect(sdkResults[INCOMPLETE], incomplete);
}

_merge(Map<String, Map<String, dynamic>> results, String sdkVersion,
        int completionTime) =>
    completionReductionMerge(
        results, completionReducer(sdkVersion, [completionTime, 99], {}));
