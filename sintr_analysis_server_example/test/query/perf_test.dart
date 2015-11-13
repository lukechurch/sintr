// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.perf.test;

import 'package:test/test.dart';
import 'package:sintr_worker_lib/query/perf.dart';

main() {
  test('perfReducer', () {
    Map<String, Map<String, dynamic>> results = {};

    results = perfReducer(
        'sdk1', ['session1', 111, ANALYSIS_PERF, 'mth1', 182], results);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {200: 1}
            }
          }
        }));

    results = perfReducer(
        'sdk1', ['session1', 111, ANALYSIS_PERF, 'mth1', 12], results);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {50: 1, 200: 1}
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
              'mth1': {50: 1, 200: 2}
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
              'mth1': {50: 1, 200: 2},
              'mth2': {50: 1}
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
              'mth1': {50: 1, 200: 2},
              'mth2': {50: 1}
            },
            INTERNAL_PERF: {
              'mth3': {50: 1}
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
              'mth1': {50: 1, 200: 2},
              'mth2': {50: 1}
            },
            INTERNAL_PERF: {
              'mth3': {50: 1}
            }
          },
          'sdk2': {
            INTERNAL_PERF: {
              'mth3': {400: 1}
            }
          }
        }));
  });

  test('perfReductionMerge', () {
    var results1 = {
      'sdk1': {
        ANALYSIS_PERF: {
          'mth1': {50: 1, 200: 2},
          'mth2': {50: 1}
        },
        INTERNAL_PERF: {
          'mth3': {50: 1}
        }
      },
      'sdk2': {
        INTERNAL_PERF: {
          'mth3': {400: 1}
        }
      }
    };
    var results2 = {
      'sdk1': {
        ANALYSIS_PERF: {
          'mth2': {50: 1},
          'mth3': {100: 2},
        },
        INTERNAL_PERF: {
          'mth3': {50: 1}
        }
      },
      'sdk3': {
        INTERNAL_PERF: {
          'mth3': {800: 1}
        }
      }
    };

    var results = perfReductionMerge(results1, results2);
    expect(
        results,
        equals({
          'sdk1': {
            ANALYSIS_PERF: {
              'mth1': {50: 1, 200: 2},
              'mth2': {50: 2},
              'mth3': {100: 2},
            },
            INTERNAL_PERF: {
              'mth3': {50: 2}
            }
          },
          'sdk2': {
            INTERNAL_PERF: {
              'mth3': {400: 1}
            }
          },
          'sdk3': {
            INTERNAL_PERF: {
              'mth3': {800: 1}
            }
          }
        }));
  });
}
