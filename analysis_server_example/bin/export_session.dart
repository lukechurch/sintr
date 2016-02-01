// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:sintr_worker_lib/instrumentation_transformer.dart';

main(List<String> args) async {
  // Extract arguments
  if (args.length != 1) {
    print("Decompression details of a session to standard out");
    print("Usage: export_session.dart filePath");
    io.exit(1);
  }
  String path = args[0];
  List<io.FileSystemEntity> files;
  files = [new io.File(path)];

  // Extract from each file
  for (io.FileSystemEntity file in files) {
    if (file is io.File) {
      print('----- extracting from $file');
      var stopwatch = new Stopwatch()..start();

      // Extraction
      await for (String logEntry in file
          .openRead()
          .transform(UTF8.decoder)
          .transform(new LineSplitter())
          .transform(new LogItemTransformer(allowNonSequentialMsgs: true))
          .handleError((e, s) {
        print("Error reading line\n${trim300(e.toString())}\n$s");
      })) {
        print(logEntry);
      }
      stopwatch.stop();
      print('extraction complete in ${stopwatch.elapsedMilliseconds} ms');
    }
  }
}
