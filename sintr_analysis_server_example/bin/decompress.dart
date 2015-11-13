// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sintr_worker_lib/instrumentation_transformer.dart';

/// Decompress a compressed instrumentation file.
main(List<String> args) async {
  if (args.length != 1) {
    print('Usage: decompress filePath');
    exit(1);
  }

  // Initialization
  final path = args[0];
  var srcName = basename(path);
  if (!srcName.startsWith('compressed-')) throw 'file is already decompressed';
  var srcFile = new File(path);
  if (!srcFile.existsSync()) throw 'cannot find $path';
  var dstName = srcName.substring(11);
  var dstFile = new File(join(srcFile.parent.path, dstName));
  if (dstFile.existsSync()) throw 'uncompressed file already exists';

  // Decompress
  print('Decompressing $srcFile\n to $dstFile');
  var sink = dstFile.openWrite();
  await for (String logEntry in srcFile
      .openRead()
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .transform(new LogItemTransformer())
      .handleError((e, s) {
    print("Error reading line\n${trim300(e.toString())}\n$s");
  })) {
    sink.writeln(logEntry);
  };
  await sink.close();
  print('Finished decompressing');
}
