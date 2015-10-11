// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:gcloud/db.dart' as db;
import 'package:gcloud/service_scope.dart' as ss;
import 'package:gcloud/src/datastore_impl.dart' as datastore_impl;
import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart';
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/logging_utils.dart';
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_common/tasks.dart' as tasks;
import 'package:sintr_common/tasks.dart' as task;

main(List<String> args) async {
  setupLogging();

  String projectId = "liftoff-dev";
  String resultsBucket = "liftoff-dev-results";
  int bucketSize = 100;

  config.configuration = new config.Configuration(projectId,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await getAuthedClient();

  var stor = await new storage.Storage(client, projectId);
  List<storage.BucketEntry> entries =
      await stor.bucket(resultsBucket).list().toList();

  print("Entries listed");

  for (var entry in entries) {
    print(entry.name);
    await stor.bucket(resultsBucket).delete(entry.name);
  }

  print("Old results deleted");

  tasks.TaskController taskController =
      new tasks.TaskController("example_task");

  var datastore = new datastore_impl.DatastoreImpl(client, 's~$projectId');
  var datastoreDB = new db.DatastoreDB(datastore);

  log.info("Setup done");

  ss.fork(() async {
    db.registerDbService(datastoreDB);

    await taskController.deleteAllTasks();
  });
  print("Tasks deleted");
}

// await taskController.deleteAllTasks();
// log.info("Tasks deleted");

// tasks.TaskController taskController =
//     new tasks.TaskController("example_task");
