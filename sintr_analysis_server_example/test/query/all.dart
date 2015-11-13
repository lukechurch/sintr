// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.query.test_all;

import 'completion_metrics_test.dart' as completion_metrics;
import 'perf_test.dart' as perf;
import 'session_ldap_test.dart' as session_ldap;
import 'session_metrics_test.dart' as session_metrics;

main() {
  completion_metrics.main();
  perf.main();
  session_ldap.main();
  session_metrics.main();
}