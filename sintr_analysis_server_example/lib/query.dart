// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.query;

import 'dart:async';

/// [Mapper] is the base interface used by worker isolates to extract results
/// from a given target.
///
/// * [#init] is called once with the extraction target
/// * [#map] is called once for each message in the extraction target
/// * [#cleanup] is called once after processing is complete
///
abstract class Mapper {
  /// Perform mapper initialization.
  /// Return a [Future] indicating when initialization is complete.
  /// Subtypes may override this method.
  Future init(Map<String, dynamic> sessionInfo) async => null;

  /// Process the given message and return a result, which may be `null`.
  /// Subtypes must implement this method.
  String map(String message);

  /// Perform cleanup and return any remaining results.
  /// Subtypes may override this method.
  List<String> cleanup() => [];
}
