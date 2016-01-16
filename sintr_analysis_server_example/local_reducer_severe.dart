// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/query/severe_log.dart';


main(List<String> args) async {
  Map versions_sessions_count = {};

  if (args.length != 1) {
    print("Runs the reducers on a set of result files locally");
    print("Usage: test_reduce_driver.dart folder");
    io.exit(1);
  }

  Map inMemoryKV = {};
  String path = args[0];
  num totalLinesProcessed = 0;


  var fses = new io.Directory(path).listSync();

  int i = 0;

  for (var fse in fses) {
    String sessionId = fse.path.split('/').last;
    if (++i % 1000 == 0) print (i);

    if (fse.path.endsWith(".gstmp")) continue;
    var f = new io.File(fse.path);
    var jsonMap = JSON.decode(f.readAsStringSync());

    List results = jsonMap["result"];
    totalLinesProcessed += jsonMap["linesProcessed"] ?? 0;

    if (results == null) continue;
    if (results.isEmpty) continue;
    for (var result in results) {
      var k = result[0];
      var v = result[1];

      var versionString = k;
      var exceptionCount = v[1]['counts:'].values.fold(0, (x, y) => x + y);

      var sessionMap = versions_sessions_count.putIfAbsent(versionString, () => {});
      sessionMap[sessionId] = exceptionCount;


      inMemoryKV.putIfAbsent(k, () => []);
      inMemoryKV[k].add(v);
      // print (r);
      // usage = completionReducer(r, usage);
      // usage = servereDateIncrementalReducer(r, usage);
    }
  }

  var finalResults = {};
  var flattenedResults = [];
  Map results = {};

print ("Lines read: $totalLinesProcessed");

  Set<String> allVersions = new Set<String>();

  for (var k in inMemoryKV.keys) {
    print(k);
    results = severeLogCountReducer(k, inMemoryKV[k], results);
  }

  results.forEach((kk, vv) {

      if (finalResults.containsKey(kk)) {
        throw "Invariant failure reducer keys overlapped";
      }

      var splits = kk.split('-');

      DateTime dt = new DateTime(int.parse(splits[0]), int.parse(splits[1]), int.parse(splits[2]));

      // Result filtering
      if (dt.difference(new DateTime.now()).abs().inDays < 30) {
        finalResults.putIfAbsent(dt.millisecondsSinceEpoch, () => vv);
        vv.forEach((version, count) {
          allVersions.add(version);
        });
      }
      // finalResults[kk] = vv;
    });



  List<String> allVersionsList = allVersions.toList();

  finalResults.forEach((date, Map versions) {
    var dateData = {"Date" : date};
    for (String version in allVersionsList) {
      if (versions.containsKey(version)) {
        dateData[version] = versions[version];
      } else {
        dateData[version] = 0;
      }
    }
    flattenedResults.add(dateData);
  });

  // Transcode for rendering

  print ("Total lines: $totalLinesProcessed");

  print ("Date, Version, Count");
  print (JSON.encode(flattenedResults));

  print ("Version: Files with errors");
  // for (var version in versions_sessions_count.keys) {
  String version = "1.13.0-dev.7.12";
  {
    print (version);
    versions_sessions_count[version].forEach((k, v) => print ("\t$k: $v"));
  }




}
//
// Map servereDateIncrementalReducer(String logLine, Map previousResults) {
//   Map newResults = {};
//   newResults.addAll(previousResults);
//
//   if (logLine.contains("SEVERE")) {
//     int dateMs = int.parse(logLine.split(":")[0].split("~")[1]);
//     var date = new DateTime.fromMillisecondsSinceEpoch(dateMs);
//
//     // Bucket by year, month, day
//     String dateStr = "${date.year}-${date.month}-${date.day}";
//     newResults.putIfAbsent(dateStr, () => 0);
//     newResults[dateStr]++;
//   }
//
//   return newResults;
// }


Map mergeResults(Map results1, Map results2) {
  Map newMerged = {};

  newMerged.addAll(results1);

  for (var k in results2.keys) {
    newMerged.putIfAbsent(k, () => 0);
    newMerged[k] += results2[k];
  }

  return newMerged;
}
