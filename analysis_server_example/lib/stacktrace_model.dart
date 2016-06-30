// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_analysis_server_example.stacktrace_model;

import 'package:nectar/clusterers.dart' as cluster;
import 'package:nectar/distance_measures.dart' as distances;

class StackTrace {
  List<String> locations;
  String fullMessage;
  String rawSourceString;
  String sessionLocation;
  int count;

  StackTrace(this.locations,
      [this.fullMessage, this.count = 1, this.sessionLocation]);

  String toString() {
    StringBuffer buffer = new StringBuffer();
    buffer.write("Count: $count\n");
    buffer.write("Session: $sessionLocation\n");
    buffer.write(locations.join("\n"));
    buffer.writeln();
    buffer.write("Original message:\n");
    buffer.write(fullMessage);

    return buffer.toString();
  }

  StackTrace.fromString(String str,
      [String fullMessage, int count = 1, String sessionLocation])
      : this(str.split('\n').map((f) => f.trim()).toList(), fullMessage, count,
            sessionLocation);

  StackTrace.fromAnalysisServerString(String str,
      [String fullMessage, int count = 1, String sessionLocation]) {
    this.fullMessage = fullMessage;
    this.count = count;
    this.sessionLocation = sessionLocation;

    this.rawSourceString = str;

    // Strip anything before "Caused by"
    if (str.contains("Caused by")) {
      str = str.substring(str.lastIndexOf("Caused by"));
    }

    // Strip anything before "StackTrace"
    String testStr = 'stackTrace"::';
    if (str.contains(testStr)) {
      str = str.substring(str.indexOf(testStr) + testStr.length + 1) ;
    }

    // str = str.replaceAll("\\n", "\n");

    List<String> lines = str.split("\\n");
    List<String> newLines = [];

    for (String ln in lines) {
      ln = ln.trim();
      if (ln.isEmpty) continue;
      if (!ln.startsWith("#")) continue;

      if (ln.contains("::")) {
        ln = ln.substring(0, ln.lastIndexOf("::"));
      }
      newLines.add(ln);
    }
    locations = newLines;
  }

  static double distance(cluster.DataItem a, cluster.DataItem b) => distances
      .jaccardDistance(a.data.locations.toSet(), b.data.locations.toSet());

  bool equalByStackTraces(StackTrace other) {
    if (locations.length != other.locations.length) return false;

    for (int i = 0; i < locations.length; i++) {
      if (locations[i] != other.locations[i]) return false;
    }
    return true;
  }
}
