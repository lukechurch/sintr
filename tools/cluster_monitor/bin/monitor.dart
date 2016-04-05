// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:async';
import 'dart:convert';

var resultString = "";
var resultErr = "";
var resultsDataJson;
var resultsFiltered = [];
var projectID;
const POLL_DELAY = const Duration(seconds: 5);

main(List<String> args) async {
  if (args.length != 1) {
    print ("Usage: monitor.dart project-id");
    exit(1);
  }
  projectID = args[0];

  log ("Starting monitor loop for: $projectID");
  startMonitorLoop();

  log ("Starting server loop");
  startServerLoop();
}

startMonitorLoop() async {
  while (true) {
    var results =
      await Process.run("gcloud",
        ['compute', 'instances', 'list',
        '--format', 'json',
        '--project', projectID]);

    resultString = results.stdout;
    resultErr = results.stderr;
    resultsDataJson = JSON.decode(resultString);
    var nodes = [];
    for (var node in resultsDataJson) {
      var nodeMap = {};
      nodeMap["name"] = node["name"];
      nodeMap["status"] = node["status"];
      nodes.add(nodeMap);
    }
    resultsFiltered = nodes;
    log("Updated nodes list: ${nodes.length}");
    new Future.delayed(POLL_DELAY);
  }
}

startServerLoop() async {
  var requestServer =
      await HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, 10001);
  print('listening on localhost, port ${requestServer.port}');
  await for (HttpRequest request in requestServer) {
    print (resultString);
    request.response..write(JSON.encode(resultsFiltered))..close();
  }
}

log(String data) {
  print ("${new DateTime.now()}: $data");
}
