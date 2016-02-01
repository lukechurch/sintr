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

const LOOP_DELAY = const Duration(seconds: 600);
const String projectId = "liftoff-dev";

main(List<String> args) async {
  setupLogging();
  bool loop = false;

  // TODO: Replace this with the args parse package
  if (args.length != 0 && (args.length != 1 && args[0] == "--loop")) {
    print("Wait for workers to be done");
    print("Usage dart query.dart [--loop]");
    io.exit(1);
  }

  if (args.length == 1 && args[0] == "--loop") loop = true;


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
      Map<String, int> readyCounts = await taskController.queryTasksReady();

      bool readyTasksLeft = false;

      for (String key in readyCounts.keys) {
        log.info("$key: ${readyCounts[key]}");

        var readyCount = readyCounts[key];
        if (readyCount == null || readyCount == 0) {

          // No more tasks ready
          // TODO: This doesn't mean that the job is done. Improve detection
        } else {
          readyTasksLeft = true;
        }
      }

      if (!readyTasksLeft) break;

      await new Future.delayed(LOOP_DELAY);
    } while (loop);

  });
}
