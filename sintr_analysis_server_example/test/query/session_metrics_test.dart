// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.session_info_test;

import 'package:sintr_worker_lib/query/session_metrics.dart';
import 'package:test/test.dart';

main() {
  test('reductionMerge', () {
    var reduced1 = {
      '2015-04-09': {
        '1.10.0-dev.0.0-hotfix1+1': 3,
        '1.10.0-dev.0.0-hotfix1+2': 2
      },
      '2015-04-10': {'1.10.0-dev.0.0-hotfix1+1': 1}
    };
    var reduced2 = {
      '2015-04-09': {
        '1.10.0-dev.0.0-hotfix1+1': 1,
        '1.10.0-dev.0.0-hotfix1+3': 7
      },
      '2015-04-11': {'1.10.0-dev.0.0-hotfix1+1': 11}
    };
    Map reduced = sessionInfoReductionMerge(reduced1, reduced2);
    expect(reduced.length, 3);
    expect(reduced['2015-04-09'].length, 3);
    expect(reduced['2015-04-09']['1.10.0-dev.0.0-hotfix1+1'], 4);
    expect(reduced['2015-04-09']['1.10.0-dev.0.0-hotfix1+2'], 2);
    expect(reduced['2015-04-09']['1.10.0-dev.0.0-hotfix1+3'], 7);
    expect(reduced['2015-04-10'].length, 1);
    expect(reduced['2015-04-10']['1.10.0-dev.0.0-hotfix1+1'], 1);
    expect(reduced['2015-04-11'].length, 1);
    expect(reduced['2015-04-11']['1.10.0-dev.0.0-hotfix1+1'], 11);
  });
}
