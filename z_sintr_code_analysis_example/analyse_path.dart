#!/usr/bin/env dart

// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cli_util/cli_util.dart' as cli_util;

import 'dart:io' as io;
import 'dart:async';
import 'package:services/src/analyzer.dart' as analyzer;

Future<Map> analyseFolder(String path) async {

  var fileMap = {};

  var inDir = new io.Directory.fromUri(new Uri.file(path));
  String pathToSdk = cli_util.getSdkDir().path;

  analyzer.Analyzer analyzerDriver = new analyzer.Analyzer(pathToSdk);

  for (var f in inDir.listSync(recursive: true)) {
    if (f is io.File) {
      try {
        if (f.path.endsWith(".dart")) {
          var results = await analyzerDriver
              .analyze(new io.File(f.path).readAsStringSync());

          Map resultsMap = {};
          resultsMap["packageImports"] = results.packageImports;
          resultsMap["resolvedImports"] = results.resolvedImports;
          resultsMap["issues"] = [];
          results.issues
              .forEach((issue) => resultsMap["issues"].add(issue.toMap()));

          fileMap[f.path] = resultsMap;
        }
      } catch (e) {
        print("ERR: $e");
      }
    }
  }

  return fileMap;
}
