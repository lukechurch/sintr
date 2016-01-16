// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

// import 'package:sintr_worker_lib/instrumentation_lib.dart';
import 'package:sintr_worker_lib/query/versions.dart';

main(List<String> args) async {
  if (args.length != 1) {
    print("Runs the reducers on a set of result files locally");
    print("Usage: test_reduce_driver.dart folder");
    io.exit(1);
  }

  Map inMemoryKV = {};


  Map usage = {};


  String path = args[0];

  var fses = new io.Directory(path).listSync();

  for (var fse in fses) {
    if (fse.path.endsWith(".gstmp")) continue;
    var f = new io.File(fse.path);
    var jsonMap = JSON.decode(f.readAsStringSync());

    List results = jsonMap["result"];

    if (results == null) continue;
    if (results.isEmpty) continue;
    for (var result in results) {
      var k = result[0];
      var v = result[1];
      inMemoryKV.putIfAbsent(k, () => []);
      inMemoryKV[k].add(v);
      // print (r);
      // usage = completionReducer(r, usage);
      // usage = servereDateIncrementalReducer(r, usage);
    }
  }

  var finalResults = {};
  var flattenedResults = [];

  Set<String> allVersions = new Set<String>();


  for (var k in inMemoryKV.keys) {
    versionReducer(k, inMemoryKV[k]).forEach((kk, vv) {
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

    // for (var item in inMemoryKV[k]) {
    //   completionReducer(k, item, finalResults[k]);
    // }
    //
    // var r = finalResults[k][k];

    // print ("$k: ${r[MIN]}, ${r[MAX]}, ${r[AVE]}, ${r[V90TH]}, ${r[V99TH]}, ${r[VALUES].length}");
  }


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

  // for (var date in finalResults)

  // print (JSON.encode(finalResults));
  print (JSON.encode(flattenedResults));

// print (usage);

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
