// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;
import 'package:semver/semver.dart';

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

  Map<dynamic, String> fileMaps = {};
  var fses = new io.Directory(path).listSync();
  Map<String, List<String>> versionsMap = {};
  log("Index versions");

  int i = 0;
  for (var fse in fses) {
    log("${i++} / ${fses.length}");
    if (!fse.path.endsWith(".json")) continue;
    var f = new io.File(fse.path);
    var jsonMap = JSON.decode(f.readAsStringSync());

    List results = jsonMap["result"];
    if (results == null) continue;
    if (results.isEmpty) continue;
    for (var result in results) {
      var k = result[0];

      try {
        var version = new SemanticVersion.fromString(k);

        versionsMap.putIfAbsent(k, () => []).add(fse.path);
      } catch (e) {
        print ("Invalid version: $k");
      }
      break;
    }
  }

  log ("versionMap: $versionsMap");


  var versionList = versionsMap.keys.toList()..sort((a, b) {
    if (a == b) return 0;
    if (new SemanticVersion.fromString(a) > new SemanticVersion.fromString(b)) return 1;
    return -1;
  });

  var version = versionList.last;

  log ("Processing version: $version");

  log("Loading ${versionsMap[version].length} logs");

  i = 0;
  for (var path in versionsMap[version]) {
    log("${i++} / ${versionsMap[version].length}");
    // if (i++ > 1000) break;

    if (!path.endsWith(".json")) continue;
    var f = new io.File(path);
    var jsonMap = JSON.decode(f.readAsStringSync());

    List results = jsonMap["result"];
    if (results == null) continue;
    if (results.isEmpty) continue;
    for (var result in results) {
      var k = result[0];
      var v = result[1];

      fileMaps[v] = path;

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
          String stString =
              errReport.split("message\"::\"")[1].split("\\n\"}}")[0];

          st.StackTrace sts =
              new st.StackTrace.fromAnalysisServerString(
                stString, errReport, 1, fileMaps[results]);

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
    previouslyAdded.sort((a, b) => a.count.compareTo(b.count));
    for (st.StackTrace st in previouslyAdded.reversed) {
        log("Common stack: $st");
        if (st.count <= 1) break;
    }

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
