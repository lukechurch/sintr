// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;

import 'package:sintr_common/logging_utils.dart';

main() async {
  setupLogging();

  config.configuration = new config.Configuration("sintr",
    cryptoTokensLocation: "${config.userHomePath}/Communications/CryptoTokens");

  await getAuthedClient();
  print ("Authed ok");
}
