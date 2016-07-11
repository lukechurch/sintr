// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

/**
 * Read all of the files in the directory given as a command-line argument, and
 * produce a JSON encoding of a map. The keys in the top-level map are dates
 * (represented as millisecond values) and the values are second-level maps. The
 * keys in the second-level maps are version numbers and the values are the
 * number of severe log messages recorded for that version on that day.
 */
main(List<String> args) async {
  if (args.length != 1) {
    print('Runs the reducers on a set of result files locally');
    print('Usage: local_reducer_severeCount.dart folder');
    io.exit(1);
  }
  String path = args[0];

  // {date -> {version -> count}}
  Map<int, Map<String, int>> intermediateResults = <int, Map<String, int>>{};

  List<io.FileSystemEntity> children = new io.Directory(path).listSync();
  for (io.FileSystemEntity child in children) {
    if (child is io.File) {
      if (child.path.endsWith('.gstmp')) continue;
      var jsonMap = JSON.decode(child.readAsStringSync());

      List<List<Object>> results = jsonMap['result'];

      if (results == null || results.isEmpty) continue;
      for (List<Object> result in results) {
        String version = result[0];
        List valueList = result[1]; // [keyKindString, dataMap]
        if (valueList[0] == 'SevereLog') {
          Map<String, List<int>> times = valueList[1]['times'];
          times.forEach((String message, List<int> timeList) {
            for (int time in timeList) {
              DateTime t = new DateTime.fromMillisecondsSinceEpoch(time);
              DateTime date = new DateTime(t.year, t.month, t.day);
              Map<String, int> secondLevelMap = intermediateResults.putIfAbsent(
                  date.millisecondsSinceEpoch, () => <String, int>{});
              int count = secondLevelMap.putIfAbsent(version, () => 0);
              secondLevelMap[version] = count + 1;
            }
          });
        }
      }
    }
  }

  List<Map<String, int>> finalResults = <Map<String, int>>[];
  intermediateResults.forEach((int date, Map<String, int> versionMap) {
    versionMap['Date'] = date;
    finalResults.add(versionMap);
  });

  print(JSON.encode(finalResults));
}
