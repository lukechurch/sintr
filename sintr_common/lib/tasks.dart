// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:appengine/appengine.dart' as ae;
import 'package:gcloud/db.dart' as db;
import 'package:memcache/memcache.dart' as mc;
import 'package:sintr_common/gae_utils.dart';
import 'package:sintr_common/logging_utils.dart' as logging;

const int DATASTORE_TRANSACTION_SIZE = 100;

db.DatastoreDB _db = db.dbService;
final _logger = new logging.Logger("tasks");

/// Abstraction over a piece of work to be done by a compute node
class Task {
  // Location of the object in the datastore
  final db.Key _objectKey;
  _TaskModel backingstore;

  String get _stateMemcacheKey => "$_objectKey-LifecycleState";
  String get _pingMemcacheKey => "$_objectKey-LastPing";

  /// Get the state of the task
  // The state machine for READY -> ALLOCATED is synchronised
  Future<LifecycleState> get state async {
    _logger.finer("Get state on Task for $_objectKey");
    String memcacheResult = await SafeMemcache.get(_stateMemcacheKey);

    if (memcacheResult != null) {
      LifecycleState result = _lifecyclefromInt(int.parse(memcacheResult));
      _logger.finer("Get state on Task for $_objectKey -> $result: OK");
      return result;
    }

    await _pullBackingStore();
    if (backingstore == null) return null;

    LifecycleState result = _lifecyclefromInt(backingstore.lifecycleState);
    _logger.finer("Get state on Task for $_objectKey -> $result: OK");
    return result;
  }

  /// Set the state of the task, do not use to set to ALLOCATED
  Future setState(LifecycleState state) async {
    if (state ==
        LifecycleState.ALLOCATED) throw "Setting tasks to allocated may only be done by the TaskController";

    _logger.finer("Set state on Task for $_objectKey -> $state");

    await _pullBackingStore();
    int lifeCycleStateInt = _intFromLifecycle(state);
    await SafeMemcache.set(_stateMemcacheKey, lifeCycleStateInt.toString());
    backingstore.lifecycleState = lifeCycleStateInt;
    await _pushBackingStore();

    _logger.finer("Set state on Task for $_objectKey -> $state : OK");
  }

  // Number of times this task has failed to execute
  Future<int> get failureCounts async {
    await _pullBackingStore();
    return backingstore?.failureCount;
  }

  // Last time this task was pinged as having made progress
  // Best effort syncronised
  Future<int> get lastPingEpochTime async {
    String memcacheResult = await SafeMemcache.get(_pingMemcacheKey);

    if (memcacheResult != null) {
      return int.parse(memcacheResult);
    }

    await _pullBackingStore();
    if (backingstore == null) return null;

    return backingstore.lastUpdateEpochMs;
  }

  //TODO: Generalise these to support multiple data-source strategy
  Future<CloudStorageLocation> get inputSource async {
    await _pullBackingStore();
    if (backingstore == null) return null;

    return new CloudStorageLocation(backingstore.inputCloudStorageBucketName,
        backingstore.inputCloudStorageObjectPath);
  }

  Future<CloudStorageLocation> get resultLocation async {
    await _pullBackingStore();
    if (backingstore == null) return null;

    return new CloudStorageLocation(backingstore.resultCloudStorageBucketName,
        backingstore.resultCloudStorageObjectPath);
  }

  Future<CloudStorageLocation> get sourceLocation async {
    await _pullBackingStore();
    if (backingstore == null) return null;

    return new CloudStorageLocation(backingstore.sourceCloudStorageBucketName,
        backingstore.sourceCloudStorageObjectPath);
  }

  /// Notify this task that is has made progress
  ping() async {
    await _pullBackingStore();

    int msSinceEpoch = new DateTime.now().millisecondsSinceEpoch;
    // TODO: Replace this with CAS
    SafeMemcache.set(_pingMemcacheKey, msSinceEpoch.toString());
    backingstore.lastUpdateEpochMs = msSinceEpoch;
    await _pushBackingStore();
  }

  // Update the in memory version from datastore
  Future _pullBackingStore() async {
    List<db.Model> models = await _db.lookup([_objectKey]);
    backingstore = models.first;
  }

  // Writeback the in memory version to datastore
  // NB: Datastore is eventually consistent, nodes may still see old
  // copies after this call has returned
  Future _pushBackingStore() async {
    await _db.commit(inserts: [backingstore]);
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

  _TaskModel();

  _TaskModel.fromData(
      this.parentJobName,
      CloudStorageLocation inputLocation,
      CloudStorageLocation sourceLocation,
      String this.resultCloudStorageBucketName) {
    lifecycleState = _intFromLifecycle(LifecycleState.READY);
    lastUpdateEpochMs = new DateTime.now().millisecondsSinceEpoch;
    failureCount = 0;
    inputCloudStorageBucketName = inputLocation.bucketName;
    inputCloudStorageObjectPath = inputLocation.objectPath;
    sourceCloudStorageBucketName = sourceLocation.bucketName;
    sourceCloudStorageObjectPath = sourceLocation.objectPath;
  }
}

class CloudStorageLocation {
  final String bucketName;
  final String objectPath;

  CloudStorageLocation(this.bucketName, this.objectPath);
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

  TaskController(this.jobName);

  // Get the next task that is ready for execution and switch it to
  // allocated. Returns null if there are no available tasks needing further
  // work
  Future<Task> getNextReadyTask() async {
    // TODO: Implement an error management wrapper so this is error tolerant

    final int READY_STATE = _intFromLifecycle(LifecycleState.READY);
    final int ALLOCATED_STATE = _intFromLifecycle(LifecycleState.ALLOCATED);

    var query = _db.query(_TaskModel)
      ..filter("parentJobName =", jobName)
      ..filter("lifecycleState = ", READY_STATE);

    await for (_TaskModel model in query.run()) {
      // Distributed sync on transition from READY -> ALLOCATED
      var memcache = ae.context.services.memcache;

      String _stateMemcacheKey = "${model.key}-LifecycleState";
      // Fast path test for conflict
      String memcacheState = await memcache.get(_stateMemcacheKey);

      // The key didn't exist
      if (memcacheState == null) {
        try {
          await memcache.set(_stateMemcacheKey, READY_STATE.toString(),
              action: mc.SetAction.ADD);
        } on mc.NotStoredError {
          // This doesn't matter. It just means that someone else created
          // key whilst we were trying to. The CAS call below will protect
          // against dual allocation

          // TODO: Log this as it indicates a higher probability of danger
          // of a race
        }
      }

      // Now the key will exist (assuming that we don't suffer an MC eviction)
      // We now try and take ownership of it
      var memcacheWithCAS = memcache.withCAS();

      // repeat the get call to sync the CAS tracker
      memcacheState = await memcache.get(_stateMemcacheKey);
      if (int.parse(memcacheState) != READY_STATE) {
        // Someone else has taken this task. Try the next.
        continue;
      }
      try {
        memcacheWithCAS.set(_stateMemcacheKey, ALLOCATED_STATE.toString());
      } on mc.ModifiedError {
        // Someone else has taken this task. Try the next.
        continue;
      }

      // If we got here, we own this task, it's now set to allocated
      // Update the datastore element and return it
      model.lifecycleState = ALLOCATED_STATE;

      Task task = new Task._fromTaskModel(model);
      await task._pushBackingStore();

      return task;
    }

    // We couldn't find a model that wasn't already in use
    return null;
  }

  Future createTasks(
      List<CloudStorageLocation> inputLocations,
      CloudStorageLocation sourceLocation,
      String resultCloudStorageBucketName) async {
    // TODO this needs resiliance adding to it to protect against
    // datastore errors

    var inserts = <_TaskModel>[];
    for (CloudStorageLocation inputLocation in inputLocations) {
      _TaskModel task = new _TaskModel.fromData(
          jobName, inputLocation, sourceLocation, resultCloudStorageBucketName);
      inserts.add(task);

      if (inserts.length >= DATASTORE_TRANSACTION_SIZE) {
        await _db.commit(inserts: inserts);
        inserts.clear();
      }
    }

    if (inserts.length > 0) {
      await _db.commit(inserts: inserts);
      inserts.clear();
    }
  }
}
