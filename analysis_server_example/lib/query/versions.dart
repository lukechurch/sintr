// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.query.versions;

import '../session_info.dart';
import '../query.dart';

class VersionMapper extends Mapper {
  @override
  map(String ln) {
    Map sessionInfo = parseSessionInfo(null, ln);
    addResult(sessionInfo[CLIENT_START_DATE], sessionInfo[SDK_VERSION]);
  }
}

Map versionReducer(String key, List values) {
  var versionCounts = {};

  for (var v in values) {
    versionCounts.putIfAbsent(v, () => 0);
    versionCounts[v]++;
  }
  return {key: versionCounts};
}
