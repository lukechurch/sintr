// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.instrumentation_transformer;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

/// Decode compressed chunks of instrumentation data
/// into instrumentation messages.
///
///     await for (String logEntry in file
///         .openRead()
///         .transform(UTF8.decoder)
///         .transform(new LineSplitter())
///         .transform(new LogItemTransformer())) {
///       // process logEntry
///     }
///
class LogItemTransformer extends Converter<String, List<String>> {
  @override
  List<String> convert(String input) {
    throw 'not implemented yet';
  }

  StringConversionSink startChunkedConversion(Sink<String> sink) {
    if (sink is! StringConversionSink) {
      sink = new StringConversionSink.from(sink);
    }
    return new _LogItemSink(sink);
  }
}

class _LogItemSink extends StringConversionSinkBase {
  final StringConversionSink _sink;

  // Sanity check tracking: {"sessionID":"1422988642527.3444824218750","msgN":0,
  String sessionID;
  int lastMsgN;

  /// The carry-over from the previous chunk.
  String _carry;

  _LogItemSink(this._sink);

  @override
  void addSlice(String chunk, int start, int end, bool isLast) {
    var dataMap = JSON.decode(chunk.substring(start, end));

    // Sanity check session ID
    if (sessionID != null) {
      if (dataMap["sessionID"] != sessionID) {
        throw "Two sessions in one file: $sessionID, ${dataMap[sessionID]}";
      }
    } else {
      sessionID = dataMap["sessionID"];
    }

    // Sanity check messages are sequential
    int nextMsgN = dataMap["msgN"];
    if (lastMsgN != null) {
      if (nextMsgN != lastMsgN + 1) {
        throw "Non-sequential MsgN in file: $lastMsgN, $nextMsgN";
      }
    }
    lastMsgN = nextMsgN;

    // Uncompress the data
    List<int> data = crypto.CryptoUtils.base64StringToBytes(dataMap["Data"]);
    String expanded = UTF8.decode(GZIP.decode(data));
    if (_carry != null) {
      expanded = '$_carry$expanded';
      _carry = null;
    }

    // Forward log entries
    StringBuffer logEntry;
    for (String line in new LineSplitter().convert(expanded)) {
      if (line.startsWith("~")) {
        if (logEntry != null) {
          _sink.add(logEntry.toString());
        }
        logEntry = new StringBuffer()..write(line);
      } else {
        if (logEntry != null) {
          logEntry.writeln();
          logEntry.write(line);
        } else {
          // This is probably a missing message/broken file
          throw 'Expected "~" as first char, but found $line';
        }
      }
    }
    _carry = logEntry?.toString();
    if (isLast) close();
  }

  @override
  void close() {
    if (_carry != null) {
      // Forward remaining log entry
      _sink.add(_carry);
      _carry = null;
    }
    _sink.close();
  }
}
