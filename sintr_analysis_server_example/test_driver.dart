// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/query/completion_metrics.dart';
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
  var extracted = [];

  // Initialize query specific objects
  TestMapper mapper = new TestMapper(new CompletionMapper(), path);
  var reducer = completionReducer;
  var reductionMerge = completionReductionMerge;

  // Extraction
  await mapper.init({}, (String key, value) {
    extracted.add([key, value]);
  });
  await for (String logEntry in file
      .openRead()
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .transform(new LogItemTransformer())
      .handleError((e, s) {
    ++mapper.readFailureCount;
    print("Error reading line\n${trim300(e.toString())}\n$s");
  })) {
    mapper.map(logEntry);
  }
  mapper.cleanup();

  // Reduce the information into two separate result maps
  var reduced1 = <String, dynamic>{};
  var reduced2 = <String, dynamic>{};
  int index = 0;
  while (index < extracted.length / 2) {
    reduced1 = reducer(extracted[index][0], extracted[index][1], reduced1);
    ++index;
  }
  print(reduced1);
  while (index < extracted.length) {
    reduced2 = reducer(extracted[index][0], extracted[index][1], reduced2);
    ++index;
  }
  print(reduced2);

  // Merge the result maps
  var reduced = reductionMerge(reduced1, reduced2);
  print(reduced);
}

/// [TestMapper] wraps another mapper with exception handling
/// and performance monitoring for testing purposes.
class TestMapper implements Mapper {
  AddResult addResult;
  final Mapper mapper;
  final String sessionFilePath;
  int msgCount = 0;
  int resultCount = 0;
  int failureCount = 0;
  int readFailureCount = 0;

  TestMapper(this.mapper, this.sessionFilePath);

  @override
  void cleanup() {
    mapper.cleanup();

    print('Extraction summary:');
    print('  $readFailureCount read failures');
    print('  $msgCount messages processed');
    print('  $resultCount extraction results');
    print('  $failureCount extraction exceptions');
  }

  @override
  Future init(Map<String, dynamic> sessionInfo, AddResult addResult) async {
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
    this.addResult = (String key, dynamic value) {
      var json;
      try {
        json = JSON.encode(value);
      } catch (e, s) {
        ++failureCount;
        print('JSON.encode(...) failed: ${trim300(value)}\n${trim300(e)}\n$s');
        return;
      }
      print('$key --> $json');
      addResult(key, value);
      ++resultCount;
    };
    return mapper.init(sessionInfo, this.addResult);
  }

  @override
  void map(String logEntry) {
    ++msgCount;
    try {
      mapper.map(logEntry);
    } catch (e, s) {
      ++failureCount;
      print('$e\n$s');
    }
  }
}
