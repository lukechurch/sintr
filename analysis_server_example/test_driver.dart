// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart';
import 'package:sintr_worker_lib/instrumentation_transformer.dart';
import 'package:sintr_worker_lib/query.dart';
// import 'package:sintr_worker_lib/query/completion_metrics.dart';
import 'package:sintr_worker_lib/query/severe_log.dart';

main(List<String> args) async {
  // Extract arguments
  if (args.length != 1) {
    print("Runs the analysis locally on a file or all files in a directory");
    print("Usage: test_driver.dart logFile");
    io.exit(1);
  }
  String path = args[0];
  List<io.FileSystemEntity> files;
  if (io.FileSystemEntity.isDirectorySync(path)) {
    files = new io.Directory(path).listSync().where((file) {
      var name = basename(file.path);
      return name.endsWith('.json');
    }).toList();
  } else {
    files = [new io.File(path)];
  }

  // Extract from each file
  var extracted = [];
  for (io.FileSystemEntity file in files) {
    if (file is io.File) {
      print('----- extracting from $file');
      var stopwatch = new Stopwatch()..start();

      // Initialize query specific objects
      TestMapper mapper = new TestMapper(new SevereLogMapper(), file.path);

      // Extraction
      await mapper.init({}, (String key, value) {
        extracted.add([key, value]);
      });
      await for (String logEntry in file
          .openRead()
          .transform(UTF8.decoder)
          .transform(new LineSplitter())
          .transform(new LogItemTransformer(allowNonSequentialMsgs: true))
          .handleError((e, s) {
        ++mapper.readFailureCount;
        print("Error reading line\n${trim300(e.toString())}\n$s");
      })) {
        mapper.map(logEntry);
        if (mapper.isMapStopped) break;
      }
      mapper.cleanup();

      stopwatch.stop();
      print('extraction complete in ${stopwatch.elapsedMilliseconds} ms');
    }
  }
  // print('----- reducing');
  //
  // // Initialize query specific objects
  // var reducer = completionReducer;
  // var reductionMerge = completionReductionMerge;
  //
  // // Reduce the information into two separate result maps
  // var reduced1 = <String, dynamic>{};
  // var reduced2 = <String, dynamic>{};
  // int index = 0;
  // while (index < extracted.length / 2) {
  //   reduced1 = reducer(extracted[index][0], extracted[index][1], reduced1);
  //   ++index;
  // }
  // print(reduced1);
  // while (index < extracted.length) {
  //   reduced2 = reducer(extracted[index][0], extracted[index][1], reduced2);
  //   ++index;
  // }
  // print(reduced2);
  //
  // // Merge the result maps
  // var reduced = reductionMerge(reduced1, reduced2);
  // print(reduced);
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
  bool get isMapStopped => mapper.isMapStopped;

  @override
  void set isMapStopped(bool _) => throw 'unsupported';

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
    if (!sessionFilePath.endsWith('.json')) {
      throw 'expected *.json but found $sessionFilePath';
    }
    // var index = sessionFilePath.indexOf('-', sessionFilePath.lastIndexOf('/'));
    // var name = sessionFilePath.substring(index + 1, sessionFilePath.length - 5);
    // Map sessionInfo;
    // if (name.startsWith('PRI')) {
    //   // Provide simplified session info for a PRI file
    //   return {SESSION_ID: name.substring(3)};
    // } else {
    //   // Read the session info from the associated PRI file
    //   var priPath = '${sessionFilePath.substring(0, index)}-PRI$name.json';
    //   Stream<List<int>> stream = new io.File(priPath).openRead();
    //   sessionInfo = await readSessionInfo(name, stream);
    // }
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
