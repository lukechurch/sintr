// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.instrumentation_processor;

import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart' as crypto;

/// Return the log entry if it is a "Log" message, otherwise return `null`
final extractLogs = (ln) {
  List<String> splits = ln.split(":");
  String msgType = splits[1];
  // int time = int.parse(splits[0].substring(1));
  if (msgType == "Log") return ln;
  else return null;
};

/// Decode chunks that have been added via [LogItemProcessor].addRawLine(...)
/// and process all resulting log messages. Append results to [#extracted]
/// if it has been supplied.
///
///     var stream = f.openRead().transform(UTF8.decoder)
///                              .transform(new LineSplitter());
///     await for (String ln in stream) {
///       proc.addRawLine(ln);
///       processMessages(proc, extracted);
///     }
///     proc.close();
///     processMessages(proc, extracted);
///
void processMessages(LogItemProcessor proc, [List<String> extracted]) {
  String nextMessage;
  while (proc.hasMoreMessages) {
    try {
      nextMessage = null;
      nextMessage = proc.readNextMessage();
    } catch (e, st) {
      var exMsg = e.toString();
      if (exMsg.length > 300) exMsg = '${exMsg.substring(0, 300)} ...';
      print("Error in line \n${exMsg} \n$st");
    }

    if (nextMessage != null) {
      print(nextMessage);
      if (extracted != null) extracted.add(nextMessage);
    }
    // if (nextMessage != null) print("${nextMessage[0]}, ${nextMessage[1]}");
    //
    // String messageType = nextMessage[1];
    // msgTyps.putIfAbsent(messageType, () => msgTyps.length);
    // print("${nextMessage[0]}, ${msgTyps[messageType]}");

  }
}

/// [InstrumentationProcessor] decodes compressed chunks of instrumentation
/// data into instrumentation messages.
class InstrumentationProcessor {
  // Sanity check tracking:   {"sessionID":"1422988642527.3444824218750","msgN":0,
  String sessionID;
  int lastMsgN;

// TODO: Turn this into a stream processor
  List<String> unusedLines = [];
  StringBuffer lastChunk = null;

  /*
   * Add a raw line from instrumentation
   */
  void addRawLine(String ln) {
    var dataMap = JSON.decode(ln);

    // Sanity check
    if (sessionID != null) {
      if (dataMap["sessionID"] != sessionID) {
        throw "Two sessions in one file: $sessionID, ${dataMap[sessionID]}";
      }
    } else {
      sessionID = dataMap["sessionID"];
    }

    int nextMsgN = dataMap["msgN"];
    if (lastMsgN != null) {
      if (nextMsgN != lastMsgN + 1) {
        throw "Non-sequential MsgN in file: $lastMsgN, $nextMsgN";
      }
    }
    lastMsgN = nextMsgN;

    // TODO: Clean this up
    List<int> data = crypto.CryptoUtils.base64StringToBytes(dataMap["Data"]);
    String expanded = UTF8.decode(io.GZIP.decode(data));
    for (String expandedLn in new LineSplitter().convert(expanded)) {
      if (expandedLn.startsWith("~") && lastChunk != null) {
        unusedLines.add(lastChunk.toString());
        lastChunk = new StringBuffer()..write(expandedLn);
      } else if (expandedLn.startsWith("~") && lastChunk == null) {
        lastChunk = new StringBuffer()..write(expandedLn);
      } else if (!expandedLn.startsWith("~") && lastChunk != null) {
        lastChunk.write(expandedLn);
      } else if (!expandedLn.startsWith("~") && lastChunk == null) {
        // This is probably a missing message/broken file
        lastChunk = new StringBuffer()..write(expandedLn);
      } else {
        // This should be impossible.
        throw "Invalid state";
      }
    }
  }

  void close() {
    if (lastChunk != null) {
      unusedLines.add(lastChunk.toString());
      lastChunk = null;
    }
  }

  String getLine() {
    if (unusedLines.isEmpty) return null;
    String data = unusedLines.first;
    unusedLines.removeAt(0);
    return data;
  }
}

/// [LogItemProcessor] decodes compressed chunks of instrumentation
/// data into instrumentation messages and feeds those messages
/// to the specified line processor.
class LogItemProcessor {
  var filterLine;
  InstrumentationProcessor processor = new InstrumentationProcessor();

  LogItemProcessor([lineProcessor]) {
    if (lineProcessor == null) {
      filterLine = extractLogs;
    } else {
      filterLine = lineProcessor;
    }
  }

  bool get hasMoreMessages => !processor.unusedLines.isEmpty;
  addRawLine(String ln) => processor.addRawLine(ln);

  close() => processor.close();
  String readNextMessage() => _processNextMessage(processor.getLine());
  String _processNextMessage(String nextMessage) {
    if (nextMessage == null) return null;

    if (!nextMessage.startsWith("~")) {
      throw "Invariant failure - bug in Instrumentation Processor: $nextMessage";
    }
    return filterLine(nextMessage);
  }
}
