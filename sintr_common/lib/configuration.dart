// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Globally available configuration information

library sintr_common.config;

import 'dart:io';

Configuration configuration;

class Configuration {
  final String projectName;
  final String cryptoTokensLocation;

  Configuration(this.projectName, {this.cryptoTokensLocation});
}

/// Return the absolute path to the current user's home directory
String get userHomePath {
  Map<String, String> envVars = Platform.environment;
  if (Platform.isMacOS || Platform.isLinux) {
    return envVars['HOME'];
  }
  if (Platform.isWindows) {
    return envVars['UserProfile'];
  }
  throw 'failed to determine user home directory';
}
