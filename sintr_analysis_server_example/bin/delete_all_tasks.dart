// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
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

  if (args.length != 0) {
    print("Clear all tasks");
    print("Usage dart delete_all_tasks.dart");
    io.exit(1);
  }

  String projectId = "liftoff-dev";

  config.configuration = new config.Configuration(projectId,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await getAuthedClient();

  log.info("All tasks deleted");

  tasks.TaskController taskController =
      new tasks.TaskController("example_task");

  var datastore = new datastore_impl.DatastoreImpl(client, 's~$projectId');
  var datastoreDB = new db.DatastoreDB(datastore);

  log.info("Setup done");

  await ss.fork(() async {
    db.registerDbService(datastoreDB);

    await taskController.deleteAllTasks();
  });
  log.info("Tasks deleted");
}
