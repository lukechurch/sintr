// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.session_info;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/completion_metrics.dart';
import 'package:sintr_worker_lib/instrumentation_processor.dart';

Future<Map> readSessionInfo(String sessionId, Stream<List<int>> stream) async {
  String firstLine;
  LogItemProcessor proc = new LogItemProcessor((line) {
    if (firstLine == null) firstLine = line;
  });
  await for (String ln
  in stream.transform(UTF8.decoder).transform(new LineSplitter())) {
    proc.addRawLine(ln);
    processMessages(proc);
  }
  proc.close();
  processMessages(proc);

  return parseSessionInfo(sessionId, firstLine);
}

Map parseSessionInfo(String sessionId, String firstLine) {
  var data = firstLine.split(':');
  return {
    'sessionId': sessionId,
    'clientStartTime': data[0].substring(1),
    'uuid': data[2],
    'clientId': data[3],
    'clientVersion': data[4],
    'serverVersion': data[5],
    'sdkVersion': data[6]
  };
}
