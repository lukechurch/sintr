library sintr_worker_lib.instrumentation_lib;


class LogItemProcessor {
  StringBuffer message = new StringBuffer();

  String processLine(String ln) {
    String lastResult = null;

    if (ln.startsWith("~")) {
      lastResult = message.toString();
      message.clear();
    }
    message.write(ln);

    if (lastResult != null) {
      List<String> splits = lastResult.split(":");
      String msgType = splits[1];

      int time = int.parse(splits[0].substring(1));
      if (msgType == "Log" && splits[2] == "SEVERE") return lastResult;
    }
  }

  String close() {
    String lastResult = message.toString();
    List<String> splits = lastResult.split(":");
    String msgType = splits[1];

    int time = int.parse(splits[0].substring(1));
    if (msgType == "Log" && splits[2] == "SEVERE") return lastResult;
  }
}
