// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:async';
import 'package:gcloud/db.dart' as db;
import 'package:gcloud/service_scope.dart' as ss;
import 'package:gcloud/src/datastore_impl.dart' as datastore_impl;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/logging_utils.dart';
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_common/tasks.dart' as tasks;

main(List<String> args) async {
  setupLogging();
  bool loop = false;

  // TODO: Replace this with the args parse package
  if (args.length != 0 && (args.length != 1 && args[0] == "--loop")) {
    print("Query the state of workers");
    print("Usage dart query.dart [--loop]");
    io.exit(1);
  }

  if (args.length == 1 && args[0] == "--loop") loop = true;

  String projectId = "liftoff-dev";

  config.configuration = new config.Configuration(projectId,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await getAuthedClient();

  tasks.TaskController taskController =
      new tasks.TaskController("example_task");

  var datastore = new datastore_impl.DatastoreImpl(client, 's~$projectId');
  var datastoreDB = new db.DatastoreDB(datastore);

  log.info("Setup done");

  await ss.fork(() async {
    db.registerDbService(datastoreDB);

    do {
      var statesCount = await taskController.queryTaskState();

      bool readyTasksLeft = false;

      for (String key in statesCount.keys) {
        var results = statesCount[key].keys.map((k) => "${tasks.LifecycleState.values[k]}: ${statesCount[key][k]}");
        log.info("$key: ${statesCount[key]} ${results.join(" ")}");

        var readyCount = statesCount[key][tasks.LifecycleState.READY.index];
        if (readyCount == null || readyCount == 0) {

          // No more tasks ready
          // TODO: This doesn't mean that the job is done. Improve detection
        } else {
          readyTasksLeft = true;
        }
      }

      if (!readyTasksLeft) break;

      await new Future.delayed(new Duration(seconds: 5));
    } while (loop);

  });
}
