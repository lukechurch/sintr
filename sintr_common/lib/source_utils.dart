// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_common.source_utils;

import 'package:crypto/crypto.dart';

/// Compute a sha of the source, canonicallised using the order
/// of the file names.
String computeCodeSha(Map<String, String> codeMap) {
  var sortedKeys = codeMap.keys.toList()..sort();

  StringBuffer sourceAggregate = new StringBuffer();
  for (String key in sortedKeys) {
    sourceAggregate.writeln(key);
    sourceAggregate.writeln(codeMap[key]);
  }

  SHA1 sha1 = new SHA1();
  sha1.add(sourceAggregate.toString().codeUnits);
  return CryptoUtils.bytesToHex(sha1.close());
}
