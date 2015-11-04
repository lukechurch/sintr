// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/instrumentation_lib.dart';
import 'package:sintr_worker_lib/session_info.dart'
    show
        sessionInfoExtractionStart,
        sessionInfoExtraction,
        sessionInfoExtractionFinished,
        sessionInfoReducer,
        sessionInfoReductionMerge;

main(List<String> args) async {
  if (args.length != 1) {
    print("Runs the analysis on a file locally");
    print("Usage: test_driver.dart logFile");
    io.exit(1);
  }

  String path = args[0];
  var sessionInfo = await loadSessionInfo(path);
  var f = new io.File(path);

  sessionInfoExtractionStart(sessionInfo);
  LogItemProcessor proc = new LogItemProcessor(sessionInfoExtraction);
  var extracted = <String>[];

  // Process each line to extract information
  await for (String ln
      in f.openRead().transform(UTF8.decoder).transform(new LineSplitter())) {
    proc.addRawLine(ln);
    processMessages(proc, extracted);
  }
  proc.close();
  processMessages(proc, extracted);

  // Finish the extraction process
  var finalResults = sessionInfoExtractionFinished();
  if (finalResults is String) {
    print(finalResults);
  } else if (finalResults is List<String>) {
    finalResults.forEach((ln) {
      extracted.add(ln);
      print(ln);
    });
  }

  // Reduce the information into two separate result maps
  var reduced1 = <String, dynamic>{};
  var reduced2 = <String, dynamic>{};
  int index = 0;
  while (index < extracted.length / 2) {
    reduced1 = sessionInfoReducer(extracted[index], reduced1);
    ++index;
  }
  print(reduced1);
  while (index < extracted.length) {
    reduced2 = sessionInfoReducer(extracted[index], reduced2);
    ++index;
  }
  print(reduced2);

  // Merge the result maps
  var reduced = sessionInfoReductionMerge(reduced1, reduced2);
  print(reduced);
}

Future<Map> loadSessionInfo(String path) async {
  if (!path.endsWith('.json')) throw 'expected *.json';
  var index = path.indexOf('-', path.lastIndexOf('/'));
  var sessionId = path.substring(index + 1, path.length - 5);
  if (sessionId.startsWith('PRI')) {
    return {'sessionId': sessionId.substring(3)};
  }

  var priPath = '${path.substring(0, index)}-PRI$sessionId.json';
  var f = new io.File(priPath);

  var firstLine;
  LogItemProcessor proc = new LogItemProcessor((line) {
    if (firstLine == null) firstLine = line;
  });
  await for (String ln
      in f.openRead().transform(UTF8.decoder).transform(new LineSplitter())) {
    proc.addRawLine(ln);
    processMessages(proc);
  }
  proc.close();
  processMessages(proc);

  var data = firstLine.split(':');
  return {
    'sessionId': sessionId,
    'clientStartTime': data[0].substring(1),
    'uuid': data[2],
    'clientId': data[3],
    'clientVersion': data[4],
    'serverVersion': data[5],
    'sdkVersion': data[6]
  };
}

void processMessages(LogItemProcessor proc, [List<String> extracted]) {
  String nextMessage;
  while (proc.hasMoreMessages) {
    try {
      nextMessage = null;
      nextMessage = proc.readNextMessage();
    } catch (e, st) {
      var exMsg = e.toString();
      if (exMsg.length > 300) exMsg = '${exMsg.substring(0, 300)} ...';
      print("Error in line \n${exMsg} \n$st");
    }

    if (nextMessage != null) {
      print(nextMessage);
      if (extracted != null) extracted.add(nextMessage);
    }
    // if (nextMessage != null) print("${nextMessage[0]}, ${nextMessage[1]}");
    //
    // String messageType = nextMessage[1];
    // msgTyps.putIfAbsent(messageType, () => msgTyps.length);
    // print("${nextMessage[0]}, ${msgTyps[messageType]}");

  }
}
