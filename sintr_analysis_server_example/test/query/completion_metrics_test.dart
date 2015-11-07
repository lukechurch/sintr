// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.completion.test;

import 'package:sintr_worker_lib/query/completion_metrics.dart';
import 'package:test/test.dart';

main() {
  test('completionReducer', () {
    Map<String, Map<String, dynamic>> results = {};

    results = completionReducer('sdk1', 24, results);
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 24, 24, 24, 24, 24, 0);

    results = completionReducer('sdk1', 12, results);
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 12, 24, 18, 24, 24, 0);

    var newValues = [];
    for (int count = 2; count <= 100; ++count) {
      newValues.add(100 + count);
    }
    newValues.shuffle();
    newValues.forEach((value) {
      results = completionReducer('sdk1', value, results);
    });
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 12, 200, 148, 190, 199, 0);

    newValues.shuffle();
    newValues.forEach((value) {
      results = completionReducer('sdk1', value, results);
    });
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 12, 200, 150, 191, 200, 0);

    results = completionReducer('sdk1', -1, results);
    expect(results, hasLength(1));
    _expectSdkResults(results['sdk1'], 12, 200, 150, 191, 200, 1);

    results = completionReducer('sdk2', 27, results);
    expect(results, hasLength(2));
    _expectSdkResults(results['sdk1'], 12, 200, 150, 191, 200, 1);
    _expectSdkResults(results['sdk2'], 27, 27, 27, 27, 27, 0);
  });

  test('completionReductionMerge', () {
    Map<String, Map<String, dynamic>> results1 = {};

    results1 = _merge(results1, 'sdk1', 12);
    expect(results1, hasLength(1));
    _expectSdkResults(results1['sdk1'], 12, 12, 12, 12, 12, 0);

    results1 = _merge(results1, 'sdk1', 24);
    expect(results1, hasLength(1));
    _expectSdkResults(results1['sdk1'], 12, 24, 18, 24, 24, 0);

    results1 = _merge(results1, 'sdk1', -1);
    expect(results1, hasLength(1));
    _expectSdkResults(results1['sdk1'], 12, 24, 18, 24, 24, 1);

    results1 = _merge(results1, 'sdk1', -2);
    expect(results1, hasLength(1));
    _expectSdkResults(results1['sdk1'], 12, 24, 18, 24, 24, 2);

    results1 = _merge(results1, 'sdk2', 27);
    expect(results1, hasLength(2));
    _expectSdkResults(results1['sdk1'], 12, 24, 18, 24, 24, 2);
    _expectSdkResults(results1['sdk2'], 27, 27, 27, 27, 27, 0);

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
    _expectSdkResults(results2['sdk1'], 102, 200, 151, 191, 200, 0);

    results2 = _merge(results2, 'sdk1', -2);
    expect(results2, hasLength(1));
    _expectSdkResults(results2['sdk1'], 102, 200, 151, 191, 200, 1);

    results2 = _merge(results2, 'sdk3', 82);
    expect(results2, hasLength(2));
    _expectSdkResults(results2['sdk1'], 102, 200, 151, 191, 200, 1);
    _expectSdkResults(results2['sdk3'], 82, 82, 82, 82, 82, 0);

    var results = completionReductionMerge(results1, results2);
    expect(results, hasLength(3));
    _expectSdkResults(results['sdk1'], 12, 200, 148, 190, 199, 3);
    _expectSdkResults(results['sdk2'], 27, 27, 27, 27, 27, 0);
    _expectSdkResults(results['sdk3'], 82, 82, 82, 82, 82, 0);
  });
}

void _expectSdkResults(Map<String, dynamic> sdkResults, int min, int max,
    int ave, int v90th, int v99th, int incomplete) {
  List<int> values = sdkResults[VALUES];
  for (int index = 1; index < values.length; ++index) {
    if (values[index - 1] > values[index]) {
      print(values);
      fail('Unsorted value at values[$index]:'
          '${values[index - 1]}, ${values[index]}');
    }
  }
  expect(sdkResults[MIN], min);
  expect(sdkResults[MAX], max);
  expect(sdkResults[AVE].round(), ave);
  expect(sdkResults[V90TH], v90th);
  expect(sdkResults[V99TH], v99th);
  expect(sdkResults[INCOMPLETE], incomplete);
}

_merge(Map<String, Map<String, dynamic>> results, String sdkVersion,
        int completionTime) =>
    completionReductionMerge(
        results, completionReducer(sdkVersion, completionTime, {}));
