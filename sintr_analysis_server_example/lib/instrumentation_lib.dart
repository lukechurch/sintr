library sintr_worker_lib.instrumentation_lib;

import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart' as crypto;

_sanityCheck(String ln) {
  //~1422655684588:Noti:
  //01234567890123456789

  List<String> splits = ln.split(":");
  String msgType = splits[1];

  // Sanity check control signature
  if (ln[0] != "~") throw "Message signature validation failed ~";
  if (ln[14] != ":") throw "Message signature validation failed :";
  if (msgType.length <
      3) throw "Message signature validation failed no Msgtype";
}

final extractLogs = (ln) {
  List<String> splits = ln.split(":");
  String msgType = splits[1];
  // int time = int.parse(splits[0].substring(1));
  if (msgType == "Log") return ln;
  else return null;
};

final extractPerf = (String ln) {
  _sanityCheck(ln);
  List<String> splits = ln.split(":");
  String msgType = splits[1];

  if (msgType == "Perf") return ln;
  else return null;

  int time = int.parse(splits[0].substring(1));
  return [time, msgType];
};

Map _reqMap = {};
final extractReqResPerf = (String ln) {
  _sanityCheck(ln);
  List<String> splits = ln.split(":");
  String msgType = splits[1];

  if (msgType != "Req" && msgType != "Res") return null;
  int time = int.parse(splits[0].substring(1));

//  ~1422652636123:Req:{"id"::"89","method"::"completion.getSuggestions","params"::{"file"::"...","offset"::152868},"clientRequestTime"::1422652634934}
// ~1422652636123:Res:{"id"::"89","result"::{"id"::"11"}}

  String dataArea = ln.substring("~1422652636123:Req:".length);
  var dataMap = JSON.decode(dataArea.replaceAll("::", ":"));
  var id = dataMap["id"];

  if (msgType == "Req") {
    _reqMap.putIfAbsent(id, () => dataMap["clientRequestTime"]);
  }

  if (msgType == "Res") {
    if (!_reqMap.containsKey(id)) {
      print("Invariant violation");
      return null;
    }

    return [id, time - _reqMap[id]];
  }
};

final extractMsgSeq = (String ln) {
  _sanityCheck(ln);

  List<String> splits = ln.split(":");
  String msgType = splits[1];

  int time = int.parse(splits[0].substring(1));
  return [time, msgType];
};




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

  addRawLine(String ln) => processor.addRawLine(ln);
  close() => processor.close();

  bool get hasMoreMessages => !processor.unusedLines.isEmpty;
  String readNextMessage() => _processNextMessage(processor.getLine());
  String _processNextMessage(String nextMessage) {
    if (nextMessage == null) return null;

    if (!nextMessage.startsWith("~")) {
      throw "Invariant failure - bug in Instrumentation Processor: $nextMessage";
    }
    return filterLine(nextMessage);
  }

}

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
      sessionID = dataMap[sessionID];
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
