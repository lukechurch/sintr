// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';

/// Compare MD5 hash of Dart vs OpenSSL
main() async {
  await compareMD5(2);
  await compareMD5(20);
  await compareMD5(2 * 1024);
}

const C = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789~-_\n';

/// Generate a random file of containing the specified number
/// of 1 Meg blocks of random characters, then calculate the MD5 hash
/// of that file using Dart crypto and OpenSSL.
Future compareMD5(int numBlocks) async {
  print('MD5 comparison - $numBlocks MB file');

  // Setup
  var tmpPath = join(Directory.systemTemp.path, 'dart_md5_test_$numBlocks');
  var tmpFile = new File(tmpPath);

  // Generate large file if does not already exist
  if (!tmpFile.existsSync()) await generateLargeFile(tmpFile, numBlocks);

  // Calculate MD5 using Dart
  var md5 = new MD5();
  await for (var bytes in tmpFile.openRead()) {
    md5.add(bytes);
  }
  List<int> dartHash = md5.close();
  print(dartHash);

  // Calculate using local Open SSL
  String md5Result = Process.runSync('openssl', ['md5', tmpPath]).stdout;
  String md5Hash = md5Result.split('= ')[1].trim();
  // Translate as hex pairs -> bytes
  List<int> openSSLHash = [];
  for (int i = 0; i < md5Hash.length; i += 2) {
    String pair = "${md5Hash.substring(i, i+2)}";
    openSSLHash.add(int.parse(pair, radix: 16));
  }
  print(openSSLHash);

  // Compare
  print('Hashes are equal ------> ${equalMd5(dartHash, openSSLHash)}');
}

/// Return `true` if the specified hashes are equal.
bool equalMd5(List<int> localMd5, List<int> remoteMd5) {
  if (localMd5.length != remoteMd5.length) return false;
  for (int index = localMd5.length - 1; index >= 0; --index) {
    if (localMd5[index] != remoteMd5[index]) return false;
  }
  return true;
}

/// Generate a random file of containing the specified number
/// of 1 Meg blocks of random characters.
Future generateLargeFile(File tmpFile, int numBlocks) async {
  print('  Generating $tmpFile ...');
  var sink = tmpFile.openWrite();
  for (int blockCount = 0; blockCount < numBlocks; ++blockCount) {
    if (blockCount % 10 == 0) print('  $blockCount of $numBlocks ...');
    var block = new StringBuffer();
    var random = new Random();
    for (int byteCount = 0; byteCount < 1024 * 1024; ++byteCount) {
      block.write(C[random.nextInt(C.length)]);
    }
    sink.write(block.toString());
    await sink.flush();
  }
  sink.write('45Dr7DX');
  await sink.close();
  print('  Generation complete');
}
