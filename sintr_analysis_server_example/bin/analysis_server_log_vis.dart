// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:sintr_worker_lib/instrumentation_transformer.dart';
import 'package:sintr_worker_lib/instrumentation_query.dart';

import 'package:many_points/many_points.dart' as viz;

const Y_OFFSET = 500;
const DEBUG = false;

int i = 0;

Map counts = {"skip" : 0, 'damaged' : 0};
Map fileYAxis = {};
Map otherAxis = {};
Map allKeyCounts = {};

viz.Visualisation ptsViz = new viz.Visualisation();

/// Decompress a compressed instrumentation file.
main(List<String> args) async {
  if (args.length != 1) {
    print('Usage: vis filePath');
    exit(1);
  }

  // Initialization
  final path = args[0];
  var srcName = basename(path);
  var srcFile = new File(path);
  if (!srcFile.existsSync()) throw 'cannot find $path';
  var dstName = "$srcName.vis";
  var dstFile = new File(join(srcFile.parent.path, dstName));

  VisExportMapper visExporter = new VisExportMapper();

  ptsViz.dataOutputFileName = "$dstName.freckl";
  ptsViz.dataOutputFolder = "${srcFile.parent.path}";
  ptsViz.imageOutputFileName = "$dstName.png";
  ptsViz.imageOutputFolder = "${srcFile.parent.path}/images/";
        // var logFile = new io.File("$clustersPath/completions/$i-$j.log");


  // Decompress
  print('Decompressing $srcFile\n to $dstFile');
  var sink = dstFile.openWrite();
  await for (String logEntry in srcFile
      .openRead()
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .transform(new LogItemTransformer())
      .handleError((e, s) {
    print("Error reading line\n${trim300(e.toString())}\n$s");
  })) {
    try {
      // if (i++ > 35000) continue;

      visExporter.map(logEntry);
    } catch (e) {
      counts['damaged']++;
    }
  }
  await sink.close();
  print('Finished exporting');
  if (DEBUG) print(counts);
  if (DEBUG) print(allKeyCounts);
  ptsViz.setColorTransform(actionMapColourTransform);
  ptsViz.render_SCALING_HACK(1000, 1000);
  print("Render done");

}

class VisExportMapper extends InstrumentationMapper {
  @override
  void mapLogMessage(int time, String msgType, String logMessageText) {


    int yVal = null;
    counts.putIfAbsent(msgType, () => 0);
    counts[msgType]++;
    String fileName = "";

    try {
      fileName = extractJsonValue(logMessageText, "file");
    } catch (e) {

    }

    String dataString = "";
    String keyString = "";

    switch (msgType) {
      case 'Req':
        String method = extractJsonValue(logMessageText, 'method');
        dataString = "$time, REQ: $method, FILE: $fileName, MESSAGE: $logMessageText";

        if (fileName == "") {
          keyString = "REQ-$method";
        }

        break;
      case 'Res':
        dataString = "$time, RES, FILE: $fileName";
        keyString = "RES";
        break;
      case 'Noti':
        String event = extractJsonValue(logMessageText, 'event');
        dataString = "$time, NOTI: $event, FILE: $fileName"; //);//   ----     $logMessageText");
        keyString = "NOTI-$event";
        counts["skip"]++;
        return;
        // break;

      case 'Read':
        fileName = logMessageText.split(':')[0];
        dataString = "$time, READ: $fileName";
        break;

      case 'Task':
      case 'Log':
        dataString = "$time, $msgType, FILE: $fileName, MESSAGE: $logMessageText";
        keyString = "LOG";
        break;

      case 'Perf':
        dataString = logMessageText;
        keyString = "PERF-${logMessageText.split(":")[0]}";
        break;
      case 'Watch':
      default:
        dataString = "Skip: $msgType, FILE: $fileName";
    }

    if (fileName != "") {
      fileYAxis.putIfAbsent(fileName, () => fileYAxis.keys.length+Y_OFFSET);
      yVal = fileYAxis[fileName];
    } else {
      if (keyString == "") {
        // We don't have either a file or key for this item, drop it with a warning
        print ("WARNING: DROPPING DATA ITEM $msgType $logMessageText");
        counts["skip"]++;
        return;
      } else {
        otherAxis.putIfAbsent(keyString, () => otherAxis.keys.length);
        yVal = otherAxis[keyString];

        if (otherAxis.length >= Y_OFFSET) {
          throw 'Y_OFFSET was insufficent to seperate between file based actions and others';
        }
      }
    }

    allKeyCounts.putIfAbsent(keyString, () => allKeyCounts.keys.length);
    int colVal = allKeyCounts[keyString];

    if (DEBUG) print ("x: $time, y: $yVal, colIndex: $colVal, Key: $keyString, data: $dataString");
    ptsViz.addData( (time/1000).floor(), yVal, colVal, {"key":keyString, "data": dataString});

  }
}


Map colourMap = {
};
Random rand = new Random();

viz.ColorTransformFunction actionMapColourTransform = (int x, int y, num value,
                                                     viz.Range xRange, viz.Range yRange, viz.Range dataRange) {

colourMap.putIfAbsent(value,
  () => viz.Color.fromRgba(
    rand.nextInt(128) + 128,
  rand.nextInt(128) + 128,
  rand.nextInt(128) + 128,
  128));

  return colourMap[value];

/*
{NOTI-server.connected: 0,
REQ-server.getVersion: 1,
RES: 2,
REQ-server.setSubscriptions: 3,
REQ-analysis.updateOptions: 4,
REQ-analysis.setAnalysisRoots: 5,
NOTI-server.status: 6,
LOG: 7,
: 8,
NOTI-analysis.errors: 9,
REQ-execution.setSubscriptions: 10, NOTI-execution.launchData: 11, REQ-analysis.setPriorityFiles: 12, REQ-analysis.setSubscriptions: 13, NOTI-analysis.outline: 14, NOTI-analysis.occurrences: 15, NOTI-analysis.navigation: 16, NOTI-analysis.highlights: 17, NOTI-analysis.overrides: 18, PERF-analysis_full: 19, REQ-search.findTopLevelDeclarations: 20, NOTI-search.results: 21, REQ-analysis.updateContent: 22, PERF-analysis_incremental: 23, NOTI-completion.results: 24, REQ-execution.createContext: 25, REQ-execution.deleteContext: 26, REQ-execution.mapUri: 27, NOTI-executiBLE: 28}

*/
  // colourMap.putIfAbsent(value, () => n)
  //
  // // Fix
  // if (value == 10) return viz.Color.fromRgb(200, 0, 0);
  //
  // // Analyze
  // if (value == 50) return viz.Color.fromRgb(100, 100, 0);
  //
  // // Complete
  // if (value == 100) return viz.Color.fromRgb(0, 0, 250);
  //
  // // Document
  // if (value == 150) return viz.Color.fromRgb(0, 100, 100);
  //
  // // Compile
  // if (value == 200) return viz.Color.fromRgb(0, 250, 0);

  // return viz.Color.fromRgb(0, 0, 0);
};
