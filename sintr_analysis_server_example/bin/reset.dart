// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:async';
import 'package:gcloud/db.dart' as db;
import 'package:gcloud/service_scope.dart' as ss;
import 'package:gcloud/src/datastore_impl.dart' as datastore_impl;
import 'package:gcloud/storage.dart' as storage;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/logging_utils.dart';
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_common/tasks.dart' as tasks;

main(List<String> args) async {
  setupLogging();

  if (args.length != 1 || args[0] != "--force") {
    print("Clear results buckets and all control datastore elements");
    print("Usage dart reset.dart --force");
    io.exit(1);
  }

  String projectId = "liftoff-dev";
  String resultsBucket = "liftoff-dev-results";

  config.configuration = new config.Configuration(projectId,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await getAuthedClient();

  var stor = await new storage.Storage(client, projectId);
  List<storage.BucketEntry> entries =
      await stor.bucket(resultsBucket).list().toList();

  print("Entries listed");

  List<Future> deleteFutures = [];

  int i = 0;
  const BLOCK_COUNT = 250;

  for (var entry in entries) {

    deleteFutures.add(stor.bucket(resultsBucket).delete(entry.name));
    if (i++ % BLOCK_COUNT == 0) {
      for (Future f in deleteFutures) {
        await f;
      }

      print ("Deleted: $i");
    }
  }
  for (Future f in deleteFutures) {
    await f;
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
