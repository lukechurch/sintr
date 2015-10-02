// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// To meet GAE needs this file must be called 'server.dart'.

import 'package:appengine/appengine.dart' as ae;
// import 'package:logging/logging.dart' as logging;
// import 'package:sintr_common/logging_utils.dart' as logging_utils;
import 'dart:io' as io;
// import 'dart:async' as async;

// import 'startup.dart';

void main(List<String> args) {
  // logging.Logger.root.level = logging.Level.ALL;

  // logging.Logger.root.fine("Before adaptor");
  // ae.useLoggingPackageAdaptor();
  // logging.Logger.root.fine("After adaptor");

  ae.runAppEngine(requestHandler);
}


void requestHandler(io.HttpRequest request) {
    //
    // request.response.headers.add('Access-Control-Allow-Methods',
    //     'GET, POST, OPTIONS');
    // request.response.headers.add('Access-Control-Allow-Headers',
    //     'Origin, X-Requested-With, Content-Type, Accept');
    //
    // request.response.statusCode = io.HttpStatus.OK;

    request.response.write("Hello worldz");
    // logging.Logger.root.fine("Message written");

    request.response.close();
}
    // logging.Logger.root.fine("Response closed");

// }
// //
// // void reoccuringLog() {
// //   int i = 0;
// //   new async.Timer.periodic(new Duration(seconds: 1), (_) {
// //     logging.Logger.root.fine("Entry ${i++}");
// //   });
// // }
//
// /**
//
//     // Map<String, String> queryParams = request.uri.queryParameters;
//     //
//     // String projectName = queryParams["projectName"];
//     // String jobName = queryParams["jobName"];
//
//     request.response.write("$queryParams \n");
//     // request.response.write("$projectName \n");
//     // request.response.write("$jobName \n");
//     //
//     // String workFolder = io.Directory.current.createTempSync().path;
//     // request.response.write(io.Directory.current.listSync(recursive: true));
//
//
//
//       //
//       //
//       //   start(projectName, jobName, workFolder).then((_)
//       // {
//       //   request.response.close();
//       //
//       // });
//
//
//
//     // // Explicitly handle an OPTIONS requests.
//     // if (request.method == 'OPTIONS') {
//     //   var requestedMethod =
//     //     request.headers.value('access-control-request-method');
//     //   var statusCode;
//     //   if (requestedMethod != null && requestedMethod.toUpperCase() == 'POST') {
//     //     statusCode = io.HttpStatus.OK;
//     //   } else {
//     //     statusCode = io.HttpStatus.BAD_REQUEST;
//     //   }
//     //   request.response..statusCode = statusCode
//     //                   ..close();
//     //   return;
//     // }
//
// */
