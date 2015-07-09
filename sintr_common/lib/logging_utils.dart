// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart' as logging;
export 'package:logging/logging.dart' show Logger;

/// Setup log streaming to the right place for local and remote deployment.
setupLogging() {
  // TODO(lukechurch): Add support for container logs
  _setupLocalLogging();
}

/// Setup log streaming to stdOut.
_setupLocalLogging() {
  // Setup the logging
  logging.Logger.root.level = logging.Level.FINE;
  logging.Logger.root.onRecord.listen((logging.LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}
