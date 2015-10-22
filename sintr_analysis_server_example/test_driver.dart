// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/instrumentation_lib.dart';

main(List<String> args) async {
  if (args.length != 1) {
    print("Runs the analysis on a file locally");
    print("Usage: test_driver.dart logFile");
    io.exit(1);
  }

  String path = args[0];
  var f = new io.File(path);

  LogItemProcessor proc = new LogItemProcessor(extractPerf);

  await for (String ln
      in f.openRead().transform(UTF8.decoder).transform(new LineSplitter())) {
    proc.addRawLine(ln);


    String nextMessage;
    while (proc.hasMoreMessages) {
      try {
        nextMessage = null;
        nextMessage = proc.readNextMessage();
      } catch (e, st) {
        print("Error in line $e $st");
      }



      if (nextMessage != null) print(nextMessage);
      // if (nextMessage != null) print("${nextMessage[0]}, ${nextMessage[1]}");
      //
      // String messageType = nextMessage[1];
      // msgTyps.putIfAbsent(messageType, () => msgTyps.length);
      // print("${nextMessage[0]}, ${msgTyps[messageType]}");

    }
  }

}
