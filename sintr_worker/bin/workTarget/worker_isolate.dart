// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:isolate';

main(List<String> args, SendPort sendPort) {
  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) {
    sendPort.send(_handle(msg));
  });
}


_handle(String msg) {
  // Unpack arguments

  var inArgs = JSON.decode(msg);

  String key = inArgs["key"];
  String value = inArgs["value"];

  return JSON.encode(map(key, value));
}

Map<String, List<String>> map(String k, String v) {
  return { k : [ v.length ] };
}
