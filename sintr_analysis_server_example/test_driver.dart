// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/completion_metrics.dart'
    show
        completionExtraction,
        completionExtractionFinished,
        completionReducer,
        completionReductionMerge;
import 'package:sintr_worker_lib/instrumentation_lib.dart';

main(List<String> args) async {
  if (args.length != 1) {
    print("Runs the analysis on a file locally");
    print("Usage: test_driver.dart logFile");
    io.exit(1);
  }

  String path = args[0];
  var f = new io.File(path);

  LogItemProcessor proc = new LogItemProcessor(completionExtraction);
  var extracted = <String>[];

  /// Process each line to extract information
  await for (String ln
      in f.openRead().transform(UTF8.decoder).transform(new LineSplitter())) {
    proc.addRawLine(ln);

    String nextMessage;
    while (proc.hasMoreMessages) {
      try {
        nextMessage = null;
        nextMessage = proc.readNextMessage();
      } catch (e, st) {
        var exMsg = e.toString();
        if (exMsg.length > 300) exMsg = '${exMsg.substring(0, 300)} ...';
        print("Error in line \n${exMsg} \n$st");
      }

      if (nextMessage != null) {
        print(nextMessage);
        extracted.add(nextMessage);
      }
      // if (nextMessage != null) print("${nextMessage[0]}, ${nextMessage[1]}");
      //
      // String messageType = nextMessage[1];
      // msgTyps.putIfAbsent(messageType, () => msgTyps.length);
      // print("${nextMessage[0]}, ${msgTyps[messageType]}");

    }
  }

  // Finish the extraction process
  var finalResults = completionExtractionFinished();
  if (finalResults is String) {
    print(finalResults);
  } else if (finalResults is List<String>) {
    finalResults.forEach((ln) {
      extracted.add(ln);
      print(ln);
    });
  }

  // Reduce the information into two separate result maps
  var reduced1 = <String, dynamic>{};
  var reduced2 = <String, dynamic>{};
  int index = 0;
  while (index < extracted.length / 2) {
    reduced1 = completionReducer(extracted[index], reduced1);
    ++index;
  }
  print(reduced1);
  while (index < extracted.length) {
    reduced2 = completionReducer(extracted[index], reduced2);
    ++index;
  }
  print(reduced2);

  // Merge the result maps
  var reduced = completionReductionMerge(reduced1, reduced2);
  print(reduced);
}
