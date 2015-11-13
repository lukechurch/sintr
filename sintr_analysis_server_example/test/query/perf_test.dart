// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.perf.test;

import 'package:sintr_worker_lib/query/perf.dart';
import 'package:test/test.dart';

main() {
  test('apiUsageReducer', () {
    Map<String, Map<String, dynamic>> results = {};

    results = apiUsageReducer(
        'sdk1', ['session1', 111, ANALYSIS_PERF, 'mth1', 182], results);
    expect(
        results,
        equals({
          'sdk1': {'mth1': 1}
        }));

    results = apiUsageReducer(
        'sdk1', ['session1', 111, ANALYSIS_PERF, 'mth1', 27], results);
    expect(
        results,
        equals({
          'sdk1': {'mth1': 2}
        }));

    results = apiUsageReducer(
        'sdk1', ['session1', 111, ANALYSIS_PERF, 'mth2', 33], results);
    expect(
        results,
        equals({
          'sdk1': {'mth1': 2, 'mth2': 1}
        }));

    results = apiUsageReducer(
        'sdk2', ['session1', 111, ANALYSIS_PERF, 'mth2', 33], results);
    expect(
        results,
        equals({
          'sdk1': {'mth1': 2, 'mth2': 1},
          'sdk2': {'mth2': 1}
        }));
  });

  test('apiUsageReductionMerge', () {
    var results1 = {
      'sdk1': {'mth1': 3, 'mth2': 7, 'mth3': 12},
      'sdk2': {'mth3': 14}
    };
    var results2 = {
      'sdk1': {'mth2': 18, 'mth3': 24, 'mth4': 133},
      'sdk3': {'mth3': 182}
    };

    var results = perfReductionMerge(results1, results2);
    expect(
        results,
        equals({
          'sdk1': {'mth1': 3, 'mth2': 25, 'mth3': 36, 'mth4': 133},
          'sdk2': {'mth3': 14},
          'sdk3': {'mth3': 182}
        }));
  });

  test('perfReducer', () {
    Map<String, Map<String, dynamic>> results = {};

    results = perfReducer(
        'sdk1', ['session1', 111, ANALYSIS_PERF, 'mth1', 182], results);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 0, 100: 0, 200: 1}
            }
          }
        }));

    results = perfReducer(
        'sdk1', ['session1', 111, ANALYSIS_PERF, 'mth1', 29], results);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1, 100: 0, 200: 1}
            }
          }
        }));

    results = perfReducer(
        'sdk1', ['session1', 111, ANALYSIS_PERF, 'mth1', 147], results);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1, 100: 0, 200: 2}
            }
          }
        }));

    results = perfReducer(
        'sdk1', ['session1', 111, ANALYSIS_PERF, 'mth2', 34], results);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1, 100: 0, 200: 2},
              'mth2': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
            }
          }
        }));

    results = perfReducer(
        'sdk1', ['session1', 111, INTERNAL_PERF, 'mth3', 37], results);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1, 100: 0, 200: 2},
              'mth2': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
            },
            INTERNAL_PERF: {
              'mth3': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
            }
          }
        }));

    results = perfReducer(
        'sdk2', ['session1', 111, INTERNAL_PERF, 'mth3', 327], results);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1, 100: 0, 200: 2},
              'mth2': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
            },
            INTERNAL_PERF: {
              'mth3': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
            }
          },
          'sdk2': {
            INTERNAL_PERF: {
              'mth3': {0: 0, 1: 0, 5: 0, 25: 0, 50: 0, 100: 0, 200: 0, 400: 1}
            }
          }
        }));
  });

  test('perfReductionMerge', () {
    var results1 = {
      'sdk1': {
        ANALYSIS_PERF: {
          'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1, 100: 0, 200: 2},
          'mth2': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
        },
        INTERNAL_PERF: {
          'mth2': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
        }
      },
      'sdk2': {
        INTERNAL_PERF: {
          'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 0, 100: 0, 200: 0, 400: 1}
        }
      }
    };
    var results2 = {
      'sdk1': {
        ANALYSIS_PERF: {
          'mth2': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
          'mth3': {0: 0, 1: 0, 5: 0, 25: 0, 50: 0, 100: 2},
        },
        INTERNAL_PERF: {
          'mth3': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1}
        }
      },
      'sdk3': {
        INTERNAL_PERF: {
          'mth3': {0: 0, 1: 0, 5: 0, 25: 0, 50: 0, 100: 0, 200: 0, 400: 0, 800: 1}
        }
      }
    };

    var results = perfReductionMerge(results1, results2);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1, 100: 0, 200: 2},
              'mth2': {0: 0, 1: 0, 5: 0, 25: 0, 50: 2},
              'mth3': {0: 0, 1: 0, 5: 0, 25: 0, 50: 0, 100: 2},
            },
            INTERNAL_PERF: {
              'mth2': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
              'mth3': {0: 0, 1: 0, 5: 0, 25: 0, 50: 1},
            }
          },
          'sdk2': {
            INTERNAL_PERF: {
              'mth1': {0: 0, 1: 0, 5: 0, 25: 0, 50: 0, 100: 0, 200: 0, 400: 1}
            }
          },
          'sdk3': {
            INTERNAL_PERF: {
              'mth3': {0: 0, 1: 0, 5: 0, 25: 0, 50: 0, 100: 0, 200: 0, 400: 0, 800: 1}
            }
          }
        }));
  });
}
