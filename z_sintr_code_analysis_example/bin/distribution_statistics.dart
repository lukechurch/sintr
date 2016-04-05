// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:convert';

int errCount = 0;
int dataItems = 0;

main(List<String> args) async {
  if (args.length != 1)  {
    print ("Usage: dart_statistics.dart <path_to_analysis_results>");
    io.exit(1);
  }

  for (var fse in new io.Directory(args[0]).listSync()) {
    var f = fse as io.File;
    if (!f.path.endsWith('gz')) continue;
    String contents = f.readAsStringSync();
    var data = JSON.decode(contents);
    var result = data['result'];

    if (result == null) {
      errCount++;
      continue;
    }

    for (var fName in result.keys) {
      // print (fName);
      var issues = result[fName]['issues'];
      Map<String, int> counts = {
        "info" : 0, "warning" : 0, "error" : 0
      };
      for (var issue in issues) {
        var kind = issue['kind'];
        counts.putIfAbsent(kind, () => 0);
        counts[kind]++;
      }

      counts['sum'] = counts.values.reduce((a, b) => a + b);
      print ("$fName, $counts".replaceAll("{", "").replaceAll("}","").replaceAll(":", ","));
    }

    // print (result.keys);
    // print (data['result'].keys);
  }
}
