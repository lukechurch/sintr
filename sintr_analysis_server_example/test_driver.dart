// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:convert';
import 'package:sintr_worker_lib/instrumentation_lib.dart';
import 'package:crypto/crypto.dart' as crypto;

main(List<String> args) async {
  if (args.length != 1) {
    print("Runs the analysis on a file locally");
    print("Usage: test_driver.dart logFile");
    io.exit(1);
  }

  String path = args[0];
  var f = new io.File(path);

  LogItemProcessor proc = new LogItemProcessor();

  await for (String ln
      in f.openRead().transform(UTF8.decoder).transform(new LineSplitter())) {
    var dataMap = JSON.decode(ln);
    List<int> data = crypto.CryptoUtils.base64StringToBytes(dataMap["Data"]);

    String expanded = UTF8.decode(io.GZIP.decode(data));
    for (String expandedLn in new LineSplitter().convert(expanded)) {
      try {
        var message = proc.processLine(expandedLn);
        if (message != null) print(message);
      } catch (e, st) {
        print("CAUGHT: $e");
        print("CAUGHT: $st");
      }
    }
  }

  try {
    String messageResult = proc.close();
    if (messageResult != null) print(messageResult);
  } catch (e, st) {
    print("CAUGHT: $e");
    print("CAUGHT: $st");
  }
}
