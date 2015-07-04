// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_common.storage_comms;

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;

import 'package:gcloud/db.dart' as db;
import 'package:gcloud/datastore.dart' as ds;


/*
 * This is the schema for response storage
 */
@db.Kind()
class ResponseBlob extends db.Model {
  @db.StringProperty()
  String jobID;

  @db.StringProperty()
  String requestID;

  @db.StringProperty()
  String requestData;

  @db.BlobProperty()
  List<int> compressedResult;

  @db.IntProperty()
  int elapsedExecutionTimeMs;

  @db.StringProperty()
  String workerRecievedDateTime;

  @db.StringProperty()
  String status;


  ResponseBlob();

  ResponseBlob.FromData(
       String jobID,
       String requestID,
       String requestData,
       String result,
       int executionTime,
       String workerRecievedDateTime,
       String status) {
    this.jobID = jobID;
    this.requestID = requestID;
    this.requestData = requestData;
    this.compressedResult = io.GZIP.encode(convert.UTF8.encode(result));
    this.elapsedExecutionTimeMs = executionTime;
    this.workerRecievedDateTime = workerRecievedDateTime;
    this.status = status;
  }

  Future record(var service) async {
    await service.commit(inserts: [this]);
  }
}