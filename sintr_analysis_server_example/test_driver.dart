// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/completion_metrics.dart';
import 'package:sintr_worker_lib/instrumentation_transformer.dart';
import 'package:sintr_worker_lib/session_info.dart';

main(List<String> args) async {
  if (args.length != 1) {
    print("Runs the analysis on a file locally");
    print("Usage: test_driver.dart logFile");
    io.exit(1);
  }

  String path = args[0];
  var sessionInfo = await loadSessionInfo(path);
  var f = new io.File(path);

  completionExtractionStart(sessionInfo);
  var extracted = <String>[];

  // Process each line to extract information
  var readFailureCount = 0;
  var msgCount = 0;
  var resultCount = 0;
  var failureCount = 0;
  await for (String logEntry in f
      .openRead()
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .transform(new LogItemTransformer())
      .handleError((e, s) {
    ++readFailureCount;
    print("Error reading line\n${trim300(e.toString())}\n$s");
  })) {
    ++msgCount;
    try {
      var result = completionExtraction(logEntry);
      if (result != null) {
        print(result);
        if (extracted != null) extracted.add(result);
        ++resultCount;
      }
    } catch (e, s) {
      ++failureCount;
      print('$e\n$s');
    }
  }
  print('Extraction summary:');
  print('  $readFailureCount read failures');
  print('  $msgCount messages processed');
  print('  $resultCount extraction results');
  print('  $failureCount extraction exceptions');

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

Future<Map> loadSessionInfo(String path) async {
  if (!path.endsWith('.json')) throw 'expected *.json';
  var index = path.indexOf('-', path.lastIndexOf('/'));
  var sessionId = path.substring(index + 1, path.length - 5);
  if (sessionId.startsWith('PRI')) {
    return {SESSION_ID: sessionId.substring(3)};
  }

  var priPath = '${path.substring(0, index)}-PRI$sessionId.json';
  var f = new io.File(priPath);
  Stream<List<int>> stream = f.openRead();

  return await readSessionInfo(sessionId, stream);
}
