// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/stacktrace_model.dart' as st;
import 'package:nectar/clusterers.dart' as cluster;

main(List<String> args) async {
  if (args.length != 2) {
    print("Runs the clusterer on a set of stack traces locally");
    print("The results are expected to be in the form of SevereLogAll");
    print("Usage: local_stacktrace_cluster.dart folder out_folder");
    io.exit(1);
  }
  Map inMemoryKV = {};
  String path = args[0];
  String outPath = args[1];

  var fses = new io.Directory(path).listSync();

  log("Loading ${fses.length} logs");

  for (var fse in fses) {
    // if (i++ > 1000) break;

    if (!fse.path.endsWith(".json")) continue;
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
    }
  }

  log("Indexing stack traces");

  Map<String, List<st.StackTrace>> stackTracesByVersion = {};

  int totalStacksProcessed = 0;

  for (var k in inMemoryKV.keys) {
    for (var results in inMemoryKV[k]) {
      if (results[0] != "SeverError") continue;

      totalStacksProcessed++;

      var counts = results[1]["counts:"];

      for (String errReport in counts.keys) {
        try {
          // print(errReport);

          String stString =
              errReport.split("message\"::\"")[1].split("\\n\"}}")[0];

          st.StackTrace sts =
              new st.StackTrace.fromAnalysisServerString(
                stString, errReport, 1);

          stackTracesByVersion.putIfAbsent(k, () => []);
          stackTracesByVersion[k].add(sts);
        } catch (e, errSt) {
          print(errReport);
          log("Failed parse: $e \n $errSt");
        }
      }
    }
  }

  print("Indexed $totalStacksProcessed stack traces");

  for (var k in stackTracesByVersion.keys) {
    int tracesVersion = stackTracesByVersion[k].length;
    print("");
    log("Processing version $k, ${tracesVersion} stacks");
    StringBuffer sb = new StringBuffer();

    Stopwatch sw = new Stopwatch()..start();

    List<cluster.DataItem> dataItems = [];
    List<st.StackTrace> previouslyAdded = [];

    for (st.StackTrace stack in stackTracesByVersion[k]) {
      bool alreadyFound = false;
      for (st.StackTrace existing in previouslyAdded) {
        if (stack.equalByStackTraces(existing)) {
          existing.count++;
          alreadyFound = true;
          break;
        }
      }

      if (!alreadyFound) {
        previouslyAdded.add(stack);
        dataItems.add(new cluster.DataItem(stack, st.StackTrace.distance));
      }
    }

    log("Unique stacks: ${dataItems.length}");

    cluster.KMedoids clusterModel = new cluster.KMedoids(dataItems);

    log("Initial cost: ${clusterModel.cost}");

    while (clusterModel.step()) {
      log("Iteration cost: ${clusterModel.cost}");
    }

    log("$tracesVersion clustered in ${sw.elapsedMilliseconds} ms");

    for (var cluster in clusterModel.clusters) {
      sb.write("==== cluster ====\n");
      sb.write(cluster);
      sb.write("==== ======= ====\n");
    }

    var f = new io.File("${outPath}/${k}.cluster");
    f.writeAsStringSync(sb.toString());
    log("$tracesVersion flushed");
  }
}

Map mergeResults(Map results1, Map results2) {
  Map newMerged = {};

  newMerged.addAll(results1);

  for (var k in results2.keys) {
    newMerged.putIfAbsent(k, () => 0);
    newMerged[k] += results2[k];
  }

  return newMerged;
}

log(String s) => print("${new DateTime.now().toIso8601String()}: $s");
