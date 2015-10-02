// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:sintr_common/logging_utils.dart' as logging;
import 'package:sintr_common/configuration.dart' as config;
// import 'package:sintr_common/instrumentation_utils.dart' as inst;

var PROJECT = 'sintr-994';

final _log = new logging.Logger("worker_isolate");

main(List<String> args, SendPort sendPort) {
  logging.setupLogging();
  _log.fine("args: $args");

  config.configuration = new config.Configuration(PROJECT,
      cryptoTokensLocation: "${config.userHomePath}/Communications/CryptoTokens");

  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) async {
    sendPort.send(await _protectedHandle(msg));
  });
}

Future<String> _protectedHandle(String msg) async {
  try {
    return JSON.encode({"result" : msg});

    // Unpack arguments
    // var inArgs = JSON.decode(msg);
    // _log.finest("inArgs: $msg");
    //
    // String key = inArgs["key"];
    //
    // var response = await map(key);
    //
    // _log.finest("response: $response");
    // return JSON.encode(response);
  } catch (e, st) {
    _log.fine("Execution erred. $e \n $st \n");
    _log.fine("Input data: $msg");
    return JSON.encode({});
  }
}

// Sample extractor
//
// Future<Map<String, List<String>>> map(String key) async {
//   Map<String, List<String>> retData = new Map<String, List<String>>();
//
//   retData["ErringFiles"] = [];
//   retData["Noti"] = [];
//
//   // Convert stream to individual lines.
//   await for (String ln in inst.logStream(key)) {
//     if (!ln.startsWith("~")) continue;
//
//     String timeStr = ln.split(':')[0].split("~")[1];
//
//     if (ln.contains('Noti:{"event"::"server.error"')) {
//       retData["ErringFiles"].add(key);
//     }
//
//     if (ln.contains("Noti")) {
//       retData["Noti"].add(timeStr);
//     }
//   }
//
//   return retData;
// }
