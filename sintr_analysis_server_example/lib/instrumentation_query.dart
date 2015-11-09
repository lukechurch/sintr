// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.instrumentation_query;

import 'package:sintr_worker_lib/query.dart';

/// [InstrumentationMapper] is a specialized [Mapper] for extracting results
/// from analysis server session logs.
abstract class InstrumentationMapper extends Mapper {
  @override
  void map(String logEntryText) {
    if (logEntryText == null || logEntryText == "") return null;
    if (!logEntryText.startsWith("~")) return null;

    int index1 = logEntryText.indexOf(':', 1);
    if (index1 == -1) return null;
    int time = int.parse(logEntryText.substring(1, index1));

    int index2 = logEntryText.indexOf(':', index1 + 1);
    if (index2 == -1) return null;
    String msgType = logEntryText.substring(index1 + 1, index2);

    String message = logEntryText.substring(index2 + 1);
    mapMessage(time, msgType, message);
  }

  /// Process the given message and call [addResult] zero or more times
  /// to provide results from processing the given message.
  void mapMessage(int time, String msgType, String message);
}
