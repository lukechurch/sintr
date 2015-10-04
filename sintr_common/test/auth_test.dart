// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/configuration.dart' as config;
import 'package:test/test.dart';

main() async {
  test('client', () async {
    expect(await testClient, isNotNull);
  });
}

var _testClient;

get testClient async {
  if (_testClient == null) {
    config.configuration = new config.Configuration('sintr-test',
        cryptoTokensLocation:
            "${config.userHomePath}/Communications/CryptoTokens");
    _testClient = await auth.getAuthedClient();
  }
  return _testClient;
}
