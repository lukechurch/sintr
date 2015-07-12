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

const basic_info_key = 'basic_info';
const unknown_value = 'unknown';
const data_prefix = 'Data :: ~';

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
    if (line.startsWith(data_prefix)) {
      // Extract the info and add a result of the format
      // <millisSinceEpoch>:Ver:<uuid>:<clientId>:<clientVersion>:<serverVersion>:<sdkVersion>
      result[basic_info_key] = [line.substring(data_prefix.length)];
      return result;
    }
  }
  result[basic_info_key] = [unknown_value];
  return result;
}

Future<Map<String, List<String>>> reduce(
    String basicKey, Stream<String> stream) async {
  if (!basicKey.startsWith(key_prefix)) throw 'unknown key: $basicKey';
  var dateSuffix = basicKey.substring(key_prefix.length);
  // Map of clientId:clientVersion to set of UUID
  Map<String, Set<String>> clientMap = {};
  Map<String, Set<String>> serverMap = {};
  Map<String, Set<String>> sdkMap = {};
  await for (String line in stream) {
    // <uuid>:<clientId>:<clientVersion>:<serverVersion>:<sdkVersion>
    var split = line.split(':');
    var uuid = split[0];
    var clientId = split[1];
    var clientVersion = split[2];
    var clientKey = '$clientId:$clientVersion';
    var serverVersion = split[3];
    var sdkVersion = split[4];
    clientMap.putIfAbsent(clientKey, () => new Set()).add(uuid);
    serverMap.putIfAbsent(serverVersion, () => new Set()).add(uuid);
    sdkMap.putIfAbsent(sdkVersion, () => new Set()).add(uuid);
  }
  return {
    // List of <clientId>:<clientVersion>:<numOfUsers>
    'clients_$dateSuffix':
        clientMap.keys.map((k) => '$k:${clientMap[k].length.toString()}'),
    // List of <serverVersion>:<numOfUsers>
    'servers_$dateSuffix':
        serverMap.keys.map((k) => '$k:${serverMap[k].length.toString()}'),
    // List of <sdkVersion>:<numOfUsers>
    'sdks_$dateSuffix':
        sdkMap.keys.map((k) => '$k:${sdkMap[k].length.toString()}'),
  };
}
