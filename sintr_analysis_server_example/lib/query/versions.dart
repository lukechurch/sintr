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
    var clientDate = new DateTime.fromMillisecondsSinceEpoch(
        int.parse(sessionInfo[CLIENT_START_TIME]));
    var dateString = "${clientDate.year}-${clientDate.month}-${clientDate.day}";
    return [dateString, sessionInfo[SDK_VERSION]];
  }
}
