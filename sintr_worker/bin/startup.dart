// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';


import 'package:gcloud/pubsub.dart' as gPubSub;

import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/pubsub_utils.dart' as ps;
import 'package:logging/logging.dart' as logging;


final _log = new logging.Logger("worker");

main(List<String> args) async {
  if (args.length != 2) {
    print("Usage: dart startup.dart project_name control_channel");
    print (args);
    exit(1);
  }

  logging.Logger.root.level = logging.Level.ALL;
  logging.Logger.root.onRecord.listen((logging.LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  String projectName = args[0];
  String controlChannel = args[1];


  config.configuration = new config.Configuration(projectName,
  cryptoTokensLocation: "/Users/lukechurch/Communications/CryptoTokens");

  var client = await auth.getAuthedClient();
  var pubsub = new gPubSub.PubSub(client, projectName);

  String topicName = "$controlChannel-topic";
  String subscriptionName = "$controlChannel-subscription";


  gPubSub.Topic topic = await ps.getTopic(
    topicName, pubsub);

  gPubSub.Subscription subscription = await ps.getSubscription(
      subscriptionName, topicName, pubsub);

  await _setupIsolate();
  _log.finer("Isolate setup");

  while (true) {
    gPubSub.PullEvent event = await subscription.pull();
    if (event != null) {
      _handleEvent(event);
      await event.acknowledge();
    } else {
      _log.info("${new DateTime.now()}: null event");
    }
  }
}

_handleEvent(gPubSub.PullEvent event) async {
  _log.info("${new DateTime.now()}: ${event.message.asString}");

  try {
    var msgMap = JSON.decode(event.message.asString);
    var data = msgMap["data"];
    sendPort.send(data);
    _log.fine("${new DateTime.now()}: Resonse: ${await stream.first}");
  } catch (e, st) {
    print (e);
  }
}

SendPort sendPort;
ReceivePort receivePort;

StreamController controller = new StreamController();
Stream stream;

_setupIsolate() async {
  receivePort = new ReceivePort();
  stream = controller.stream.asBroadcastStream();
  receivePort.listen((msg) {
    if (sendPort == null) {
      sendPort = msg;
    } else {
      controller.add(msg);
    }
  });

  String workerUri = 'worker_isolate.dart';
  Isolate.spawnUri(Uri.parse(workerUri), [], receivePort.sendPort).then((isolate) {
    _log.info("Worker isolate spawned");
  });
}