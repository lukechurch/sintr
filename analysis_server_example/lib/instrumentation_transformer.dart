// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.instrumentation_transformer;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;

/// Return a string that is at most 300 char long.
String trim300(String exMsg) {
  if (exMsg.length <= 300) return exMsg;
  return '${exMsg.substring(0, 296)} ...';
}

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
  /// `true` if non-sequential message blocks should be tolerated
  /// or `false` if an exception should be thrown.
  final bool allowNonSequentialMsgs;

  _LogItemSink _logSink;

  LogItemTransformer({this.allowNonSequentialMsgs: false});

  /// The MsgN of the last message in the session log.
  int get lastMsgN => _logSink.lastMsgN;

  /// The number of missing messages.
  int get missingMsgCount => _logSink.missingMsgCount;

  @override
  List<String> convert(String input) {
    throw 'not implemented yet';
  }

  StringConversionSink startChunkedConversion(Sink<String> sink) {
    if (sink is! StringConversionSink) {
      sink = new StringConversionSink.from(sink);
    }
    _logSink = new _LogItemSink(sink, allowNonSequentialMsgs);
    return _logSink;
  }
}

class _LogItemSink extends StringConversionSinkBase {
  final StringConversionSink _sink;

  // Sanity check tracking: {"sessionID":"1422988642527.3444824218750","msgN":0,
  String sessionID;
  int lastMsgN = -1;

  /// The carry-over from the previous chunk.
  String _carry;

  /// `true` if non-sequential message blocks should be tolerated
  /// or `false` if an exception should be thrown.
  bool allowNonSequentialMsgs;

  /// The number of missing messages.
  int missingMsgCount = 0;

  _LogItemSink(this._sink, this.allowNonSequentialMsgs);

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
    bool ignorePartialMsgLines = false;
    int nextMsgN = dataMap["msgN"];
    if (nextMsgN != lastMsgN + 1) {
      // Clear any carry over from the previous block
      // and ignore any partial msg lines at the beginning of the block
      _carry = null;
      ignorePartialMsgLines = true;
      missingMsgCount += max(nextMsgN - lastMsgN - 1, 0);

      // Throw an exception if non-sequential blocks are not allowed
      if (!allowNonSequentialMsgs || nextMsgN < lastMsgN + 1) {
        var exMsg = "Non-sequential MsgN in file: $lastMsgN, $nextMsgN";
        lastMsgN = nextMsgN;
        throw exMsg;
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
        ignorePartialMsgLines = false;
        if (logEntry != null) {
          _sink.add(logEntry.toString());
        }
        logEntry = new StringBuffer()..write(line);
      } else {
        // If a non-sequential block was encountered
        // then ignore any partial msg lines at the beginning of the block
        if (ignorePartialMsgLines) continue;

        // Build the log entry to be forwarded
        if (logEntry != null) {
          logEntry.writeln();
          logEntry.write(line);
        } else {
          // This is probably a missing message/broken file
          throw 'Expected "~" as first char, but found ${trim300(line)}';
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
