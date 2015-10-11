// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_common.tasks;

import 'dart:async';

import 'package:gcloud/db.dart' as db;
import 'package:sintr_common/gae_utils.dart';
import 'package:sintr_common/logging_utils.dart' as log;
import 'package:uuid/uuid.dart';

const int DATASTORE_TRANSACTION_SIZE = 100;
const String _UNALLOCATED_OWNER = "";

db.DatastoreDB _db = db.dbService;

/// Abstraction over a piece of work to be done by a compute node
class Task {
  // Location of the object in the datastore
  final db.Key _objectKey;
  _TaskModel backingstore;

  toString() => uniqueName;

  String get uniqueName => "${_objectKey?.id}";

  /// Get the state of the task
  // The state machine for READY -> ALLOCATED is synchronised
  Future<LifecycleState> get state async {
    log.trace("Get state on Task for $_objectKey");
    await _pullBackingStore();
    if (backingstore == null) return null;

    LifecycleState result = _lifecyclefromInt(backingstore.lifecycleState);
    log.trace("Get state on Task for $_objectKey -> $result: OK");
    return result;
  }

  // TODO(lukechurch): This needs adapting to use the owner field to ensure
  // that we successfully take ownership of the node
  Future setState(LifecycleState state) async {
    if (state == LifecycleState.ALLOCATED) {
      throw "Setting tasks to allocated may only be done by the TaskController";
    }
    log.trace("Set state on Task for $_objectKey -> $state");

    await _pullBackingStore();
    int lifeCycleStateInt = _intFromLifecycle(state);
    backingstore.lifecycleState = lifeCycleStateInt;
    await _pushBackingStore();

    log.trace("Set state on Task for $_objectKey -> $state : OK");
  }

  // Number of times this task has failed to execute
  Future<int> get failureCounts async {
    log.trace("Get failureCounts on Task for $_objectKey");

    await _pullBackingStore();
    return backingstore?.failureCount;
  }

  // Last time this task was pinged as having made progress
  // Best effort syncronised
  Future<int> get lastUpdateEpochMs async {
    log.trace("Get lastUpdateEpochMs on Task for $_objectKey");
    await _pullBackingStore();
    if (backingstore == null) return null;

    return backingstore.lastUpdateEpochMs;
  }

  //TODO: Generalise these to support multiple data-source strategy
  Future<CloudStorageLocation> get inputSource async {
    log.trace("Get inputSource on Task for $_objectKey");

    await _pullBackingStore();
    if (backingstore == null) return null;

    return new CloudStorageLocation(backingstore.inputCloudStorageBucketName,
        backingstore.inputCloudStorageObjectPath);
  }

  Future<CloudStorageLocation> get resultLocation async {
    log.trace("Get resultLocation on Task for $_objectKey");

    await _pullBackingStore();
    if (backingstore == null) return null;

    return new CloudStorageLocation(backingstore.resultCloudStorageBucketName,
        backingstore.resultCloudStorageObjectPath);
  }

  Future<CloudStorageLocation> get sourceLocation async {
    log.trace("Get sourceLocation on Task for $_objectKey");

    await _pullBackingStore();
    if (backingstore == null) return null;

    return new CloudStorageLocation(backingstore.sourceCloudStorageBucketName,
        backingstore.sourceCloudStorageObjectPath);
  }

  /// Record that this task has made progress
  recordProgress() async {
    log.trace("recordProgress on Task for $_objectKey");
    await _pullBackingStore();

    int msSinceEpoch = new DateTime.now().millisecondsSinceEpoch;
    backingstore.lastUpdateEpochMs = msSinceEpoch;
    await _pushBackingStore();
  }

  // Update the in memory version from datastore
  Future _pullBackingStore() async {
    var sw = new Stopwatch()..start();
    log.trace("_pullBackingStore on Task for $_objectKey");

    List<db.Model> models = await _db.lookup([_objectKey]);
    backingstore = models.first;

    log.trace("_pullBackingStore completed, PERF: ${sw.elapsedMilliseconds}");
  }

  // Writeback the in memory version to datastore
  // NB: Datastore is eventually consistent, nodes may still see old
  // copies after this call has returned
  Future _pushBackingStore() async {
    var sw = new Stopwatch()..start();
    log.trace("_pushBackingStore on Task for $_objectKey");

    await _db.commit(inserts: [backingstore]);

    log.trace("_pushBackingStore completed, PERF: ${sw.elapsedMilliseconds}");
  }

  Task._fromTaskKey(this._objectKey);

  Task._fromTaskModel(_TaskModel backingstore)
      : this._objectKey = backingstore.key,
        this.backingstore = backingstore;
}

/// Datamodel for storing tasks in Datastore
@db.Kind()
class _TaskModel extends db.Model {
  @db.StringProperty()
  String parentJobName;

  @db.IntProperty()
  int lifecycleState;

  @db.IntProperty()
  int lastUpdateEpochMs;

  @db.IntProperty()
  int failureCount;

  @db.StringProperty()
  String inputCloudStorageBucketName;

  @db.StringProperty()
  String inputCloudStorageObjectPath;

  @db.StringProperty()
  String resultCloudStorageBucketName;

  @db.StringProperty()
  String resultCloudStorageObjectPath;

  @db.StringProperty()
  String sourceCloudStorageBucketName;

  @db.StringProperty()
  String sourceCloudStorageObjectPath;

  @db.StringProperty()
  String ownerID;

  _TaskModel();

  _TaskModel.fromData(
      this.parentJobName,
      CloudStorageLocation inputLocation,
      CloudStorageLocation sourceLocation,
      String this.resultCloudStorageBucketName) {
    lifecycleState = _intFromLifecycle(LifecycleState.READY);
    lastUpdateEpochMs = new DateTime.now().millisecondsSinceEpoch;
    failureCount = 0;
    ownerID = _UNALLOCATED_OWNER;
    inputCloudStorageBucketName = inputLocation.bucketName;
    inputCloudStorageObjectPath = inputLocation.objectPath;
    sourceCloudStorageBucketName = sourceLocation.bucketName;
    sourceCloudStorageObjectPath = sourceLocation.objectPath;
  }
}

/// [LifecycleState] tracks a task through its lifetime
enum LifecycleState {
  READY, // Ready for allocation
  ALLOCATED, // Allocated to a node
  STARTED, // Execution has begun, this may go back to READY if it fails
  DONE, // Successfully compute
  DEAD // Terminally dead, won't be retried
}

LifecycleState _lifecyclefromInt(int i) => LifecycleState.values[i];
int _intFromLifecycle(LifecycleState state) =>
    LifecycleState.values.indexOf(state);

/// Class that manages the creation and allocation of the work to be done
/// Multiple nodes are expected to make concurrent calls to this API
class TaskController {
  String jobName;
  String ownerID;

  TaskController(this.jobName) {
    // TODO(lukechurch): Replace this with a gaurenteed unqiueness
    ownerID = new Uuid().v4();
  }

  // Get the next task that is ready for execution and switch it to
  // allocated. Returns null if there are no available tasks needing further
  // work
  Future<Task> getNextReadyTask() async {
    log.trace("getNextReadyTask() started");

    // TODO: Implement an error management wrapper so this is error tolerant

    // TODO: This algorithm has a race condition where two nodes
    // can both decide they got the task.

    final int READY_STATE = _intFromLifecycle(LifecycleState.READY);
    final int ALLOCATED_STATE = _intFromLifecycle(LifecycleState.ALLOCATED);

    var query = _db.query(_TaskModel)
      ..filter("parentJobName =", jobName)
      ..filter("lifecycleState =", READY_STATE);

    await for (_TaskModel model in query.run()) {
      model.lifecycleState = ALLOCATED_STATE;
      model.ownerID = ownerID;

      Task task = new Task._fromTaskModel(model);
      await task._pushBackingStore();

      // Test to see if we got the task
      while (true) {
        await task._pullBackingStore();

        if (task.backingstore.ownerID == ownerID) {
          return task;
        } else if (task.backingstore.ownerID == _UNALLOCATED_OWNER) {
          // Datastore isn't consistent yet sync hasn't completed yet
          continue;
        }
        // Someone else got this task
        break;
      }
    }
    // We couldn't find a model that wasn't already in use
    return null;
  }

  // Utility methods
  Future createTasks(
      List<CloudStorageLocation> inputLocations,
      CloudStorageLocation sourceLocation,
      String resultCloudStorageBucketName) async {

        log.info("Creating ${inputLocations.length} tasks");

        int count = 0;

    // TODO this needs resiliance adding to it to protect against
    // datastore errors

    var inserts = <_TaskModel>[];
    for (CloudStorageLocation inputLocation in inputLocations) {
      _TaskModel task = new _TaskModel.fromData(
          jobName, inputLocation, sourceLocation, resultCloudStorageBucketName);
      inserts.add(task);

      if (inserts.length >= DATASTORE_TRANSACTION_SIZE) {
        count += inserts.length;
        await _db.commit(inserts: inserts);

        log.info("Tasks committed: $count");
        inserts.clear();
      }
    }

    if (inserts.length > 0) {
      count += inserts.length;
      await _db.commit(inserts: inserts);

      log.info("Tasks committed: $count");
      inserts.clear();
    }
  }

  Future deleteAllTasks() async {
    log.info("Deleting all tasks");

    int i = 0;
    var query = _db.query(_TaskModel);
    await for (var model in query.run()) {
      await _db.commit(deletes: [model.key]);
      i++;
    }
    log.info("$i tasks deleted");
  }
}
