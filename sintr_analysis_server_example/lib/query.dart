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
  /// A function used by the mapper to provide results to its client.
  AddResult addResult;

  ///Flag used to signal jobs manager that mapper has finished its work
  /// and [map] no longer needs to be called.
  bool isMapComplete = false;

  /// Perform mapper initialization.
  /// Return a [Future] indicating when initialization is complete.
  /// Subtypes may override this method.
  Future init(Map<String, dynamic> sessionInfo, AddResult addResult) async {
    this.addResult = addResult;
    return null;
  }

  /// Process the given message and call [addResult] zero or more times
  /// to provide results from processing the given message.
  /// Subtypes must implement this method.
  void map(String message);

  /// Perform cleanup and call [addResult] zero or more times
  /// to provide additional results.
  /// Subtypes may override this method.
  void cleanup() {}
}

/// A function passed to the mapper so that the mapper can provide results
/// to its client. The [value] must be an object that can be encoded via
/// `JSON.encode(value)`.
typedef void AddResult(String key, dynamic value);
