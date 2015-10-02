// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// To meet GAE needs this file must be called 'server.dart'.

import 'package:appengine/appengine.dart' as ae;
import 'package:sintr_common/logging_utils.dart' as logging_utils;
import 'dart:io' as io;

import 'startup.dart';

void main(List<String> args) {

  ae.useLoggingPackageAdaptor();
  logging_utils.Logger.root.

  ae.runAppEngine(requestHandler);
}

void requestHandler(io.HttpRequest request) {



    request.response.headers.add('Access-Control-Allow-Methods',
        'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers',
        'Origin, X-Requested-With, Content-Type, Accept');
        request.response.statusCode = io.HttpStatus.OK;

    Map<String, String> queryParams = request.uri.queryParameters;

    String projectName = queryParams["projectName"];
    String jobName = queryParams["jobName"];

    request.response.write(queryParams);

    String workFolder = io.Directory.current.createTempSync().path;

        start(projectName, jobName, workFolder).then(()
      {
        request.response.close();

      });



    // // Explicitly handle an OPTIONS requests.
    // if (request.method == 'OPTIONS') {
    //   var requestedMethod =
    //     request.headers.value('access-control-request-method');
    //   var statusCode;
    //   if (requestedMethod != null && requestedMethod.toUpperCase() == 'POST') {
    //     statusCode = io.HttpStatus.OK;
    //   } else {
    //     statusCode = io.HttpStatus.BAD_REQUEST;
    //   }
    //   request.response..statusCode = statusCode
    //                   ..close();
    //   return;
    // }
  }
