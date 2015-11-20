// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart' as logging;

logging.Logger _logger = new logging.Logger("sintr_common");

info(String message) => _logger.info(message);
trace(String message) => _logger.finer(message);
debug(String message) => _logger.fine(message);
alert(String message) => _logger.shout(message);

perf(String name, int ms) => _logger.fine("PERF: $name : $ms");

/// Setup log streaming to the right place for local and remote deployment.
setupLogging() {
  // TODO(lukechurch): Add support for container logs
  _setupLocalLogging();
}

/// Setup log streaming to stdOut.
_setupLocalLogging() {
  // Setup the logging
  logging.hierarchicalLoggingEnabled = false;
  logging.Logger.root.level = logging.Level.FINER;
  logging.Logger.root.onRecord.listen((logging.LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}
