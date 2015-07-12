// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:gcloud/storage.dart';
import 'package:sintr_common/logging_utils.dart' as logging;
import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/configuration.dart' as config;

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
    // Unpack arguments
    var inArgs = JSON.decode(msg);
    _log.finest("inArgs: $msg");

    String key = inArgs["key"];
    String value = inArgs["value"];

    var response = await map(key, value);

    _log.finest("response: $response");
    return JSON.encode(response);
  } catch (e, st) {
    _log.fine("Execution erred. $e \n $st \n");
    _log.fine("Input data: $msg");
    return JSON.encode({});
  }
}

Future<Map<String, List<String>>> map(String k, String v) async {
  var client = await auth.getAuthedClient();
  _log.finest("Client acquired");

  var storage = new Storage(client, "sintr-994");
  _log.finest("Storage acquired");

  Stream<String> stream = storage
      .bucket("sintr-sample-test-data")
      .read(k)
      .transform(UTF8.decoder) // Decode bytes to UTF8.
      .transform(new LineSplitter());

  return await mapStream(k, stream);
}

const key_prefix = 'basic_info_';
const unknown_value = 'unknown';

/// Extract basic information about the client (IDE) being used
Future<Map<String, List<String>>> mapStream(
    String logKey, Stream<String> stream) async {
  var result = new Map<String, List<String>>();
  await for (String line in stream) {
    if (line.startsWith('sessionID :: ')) {
      if (!line.startsWith('sessionID :: PRI')) {
        // The information is only encoded in priority streams
        return result;
      }
    }
    if (line.startsWith('msgN :: ')) {
      if (line != 'msgN :: 0') {
        // The information is only encoded in the first message
        return result;
      }
    }
    if (line.startsWith('Data :: ~')) {
      int index = line.indexOf(':Ver:');
      if (index != -1) {
        int milliSinceEpoch = int.parse(line.substring(9, index));
        var prefix = key_prefix;
        var key = buildKey(prefix, milliSinceEpoch);
        // Extract the info and add a key/value of the format
        // basic_info_<YYYY>-<MM>-<DD>
        // <uuid>:<clientId>:<clientVersion>:<serverVersion>:<sdkVersion>
        result[key] = [line.substring(index + 5)];
      }
      return result;
    }
  }
  result[key_prefix] = [unknown_value];
  return result;
}

/// Return a key of the form <prefix><YYYY>-<MM>-<DD>
String buildKey(String prefix, int milliSinceEpoch) {
  var time = new DateTime.fromMillisecondsSinceEpoch(milliSinceEpoch);
  var year = time.year.toString();
  var month = time.month.toString();
  var day = time.day.toString();
  if (month.length < 2) month = '0$month';
  if (day.length < 2) day = '0$day';
  return '$prefix$year-$month-$day';
}