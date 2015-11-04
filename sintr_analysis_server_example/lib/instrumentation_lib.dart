library sintr_worker_lib.instrumentation_lib;

import 'dart:convert';

export 'instrumentation_processor.dart';

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
