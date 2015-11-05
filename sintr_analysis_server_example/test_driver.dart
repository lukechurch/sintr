// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/completion_metrics.dart';
import 'package:sintr_worker_lib/instrumentation_transformer.dart';
import 'package:sintr_worker_lib/query.dart';
import 'package:sintr_worker_lib/session_info.dart';

main(List<String> args) async {
  // Extract arguments
  if (args.length != 1) {
    print("Runs the analysis on a file locally");
    print("Usage: test_driver.dart logFile");
    io.exit(1);
  }
  String path = args[0];
  var file = new io.File(path);
  var extracted = <String>[];

  // Initialize query specific objects
  TestMapper mapper = new TestMapper(new CompletionMapper(), path);
  var reducer = completionReducer;
  var reductionMerge = completionReductionMerge;

  // Extraction
  await mapper.init({});
  await for (String logEntry in file
      .openRead()
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .transform(new LogItemTransformer())
      .handleError((e, s) {
    ++mapper.readFailureCount;
    print("Error reading line\n${trim300(e.toString())}\n$s");
  })) {
    var result = mapper.map(logEntry);
    if (result != null) {
      extracted.add(result);
    }
  }
  extracted.addAll(mapper.cleanup());

  // Reduce the information into two separate result maps
  var reduced1 = <String, dynamic>{};
  var reduced2 = <String, dynamic>{};
  int index = 0;
  while (index < extracted.length / 2) {
    reduced1 = reducer(extracted[index], reduced1);
    ++index;
  }
  print(reduced1);
  while (index < extracted.length) {
    reduced2 = reducer(extracted[index], reduced2);
    ++index;
  }
  print(reduced2);

  // Merge the result maps
  var reduced = reductionMerge(reduced1, reduced2);
  print(reduced);
}

/// [TestMapper] wraps another mapper with exception handling
/// and performance monitoring for testing purposes.
class TestMapper extends Mapper {
  final Mapper mapper;
  final String sessionFilePath;
  int msgCount = 0;
  int resultCount = 0;
  int failureCount = 0;
  int readFailureCount = 0;

  TestMapper(this.mapper, this.sessionFilePath);

  @override
  List<String> cleanup() {
    List<String> finalResults = mapper.cleanup();
    resultCount += finalResults.length;
    finalResults.forEach((ln) => print(ln));

    print('Extraction summary:');
    print('  $readFailureCount read failures');
    print('  $msgCount messages processed');
    print('  $resultCount extraction results');
    print('  $failureCount extraction exceptions');
    return finalResults;
  }

  @override
  Future init(Map<String, dynamic> sessionInfo) async {
    if (!sessionFilePath.endsWith('.json')) throw 'expected *.json';
    var index = sessionFilePath.indexOf('-', sessionFilePath.lastIndexOf('/'));
    var name = sessionFilePath.substring(index + 1, sessionFilePath.length - 5);
    Map sessionInfo;
    if (name.startsWith('PRI')) {
      // Provide simplified session info for a PRI file
      return {SESSION_ID: name.substring(3)};
    } else {
      // Read the session info from the associated PRI file
      var priPath = '${sessionFilePath.substring(0, index)}-PRI$name.json';
      Stream<List<int>> stream = new io.File(priPath).openRead();
      sessionInfo = await readSessionInfo(name, stream);
    }
    return mapper.init(sessionInfo);
  }

  @override
  String map(String logEntry) {
    ++msgCount;
    try {
      var result = mapper.map(logEntry);
      if (result != null) {
        ++resultCount;
        print(result);
        return result;
      }
    } catch (e, s) {
      ++failureCount;
      print('$e\n$s');
    }
    return null;
  }
}
