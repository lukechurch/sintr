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
import 'package:gcloud/storage.dart' as storage;

// TODO: Migrate the parameters of this file to the configuation common lib

/// Create tasks from items in an input bucket, in [incremental] mode this
/// will only create tasks if there was no output already present.
Future createTasks(String JobName, String inputBucketName,
    List<String> objectNames, resultsBucketName, sourceBucketName,
    {incremental: false}) async {
  String projectId = config.configuration.projectName;

  var client = await getAuthedClient();
  var datastore = new datastore_impl.DatastoreImpl(client, 's~$projectId');
  var datastoreDB = new db.DatastoreDB(datastore);
  var cloudstore = new storage.Storage(client, projectId);

  log.info("Setup done");

  ss.fork(() async {
    db.registerDbService(datastoreDB);

    Set<String> existingObjectPaths = new Set<String>();
    existingObjectPaths.addAll(await cloudstore
        .bucket(resultsBucketName)
        .list()
        .map((entity) => entity.name)
        .toList());

    log.info("Existing results listed");

    tasks.TaskController taskController = new tasks.TaskController(JobName);

    var taskList = [];
    for (String objectName in objectNames) {
      var inputLocation =
          new gae_utils.CloudStorageLocation(inputBucketName, objectName);

      if (incremental) {
        // Test if the output location file exists
        // TODO(lukechurch): This is currently only checking existence
        // it should check a watermark against the last modified date
        // of the input
        var outputObjectPath =
            taskController.outputPathFromInput(inputLocation);
        if (existingObjectPaths.contains(outputObjectPath)) {
          continue;
        }
      }

      taskList.add(inputLocation);
    }

    bool ok = false;
    // Dumb retry loop
    for (int tryCount = 0; tryCount < 3; tryCount++) {
      try {
        await taskController.createTasks(
            // Input locations
            taskList,
            // Source locations
            new gae_utils.CloudStorageLocation(
                sourceBucketName, "test_worker.json"),

            // results
            resultsBucketName);
        ok = true;
        break;
      } catch (e, st) {
        print("Error: $e $st");
        print("retry");
      }
    }

    if (!ok) throw "Create tasks failed";

    log.info("Tasks created");
  });
}
