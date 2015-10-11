// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_common.task_utils;

import 'dart:async';
import 'package:gcloud/db.dart' as db;
import 'package:gcloud/service_scope.dart' as ss;
import 'package:gcloud/src/datastore_impl.dart' as datastore_impl;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:sintr_common/tasks.dart' as tasks;
import "package:sintr_common/gae_utils.dart" as gae_utils;

// TODO: Migrate the parameters of this file to the configuation common lib

Future createTasks (String bucket, List<String> objectNames) async {

  String projectId = config.configuration.projectName;

  var client = await getAuthedClient();
  var datastore = new datastore_impl.DatastoreImpl(client, 's~$projectId');
  var datastoreDB = new db.DatastoreDB(datastore);

  log.info("Setup done");

  ss.fork(() async {

    db.registerDbService(datastoreDB);

    tasks.TaskController taskController =
        new tasks.TaskController("example_task");


    var taskList = [];
    for (String objectName in objectNames) {
      taskList.add(new gae_utils.CloudStorageLocation(bucket, objectName));
    }

    await taskController.createTasks(
      // Input locations
      taskList,
    // Source locations
    new gae_utils.CloudStorageLocation("liftoff-dev-source", "test_worker.json"),

    // results
    "liftoff-dev-results");

    log.info("Tasks created");
  });

}
