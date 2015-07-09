// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:sintr_worker/basic_info.dart' as target;
import 'package:test/test.dart';

main() async {
  test('map pri 0', () async {
    var data = '''versionID :: 2015-02-04
some random lines here
msgN :: 0
Data :: ~1427794575906:Ver:1427375441782463424515:IntelliJ_IDEA:IC-141.177:1.3.0:1.9.0-dev.10.10+2
''';
    var result = await runMap(data);
    expect(result, hasLength(1));
    expect(result[target.basic_info_key], [
      '1427794575906:Ver:1427375441782463424515:IntelliJ_IDEA:IC-141.177:1.3.0:1.9.0-dev.10.10+2'
    ]);
  });

  test('map pri 1', () async {
    var data = '''versionID :: 2015-02-04
sessionID :: PRI1427794575682.9546
ServerDate-b75e7a7f-dc90-48a1-8637-dbc123175a4d :: 2015-03-31 09:36:45
RandomToken-b75e7a7f-dc90-48a1-8637-dbc123175a4d :: 0.3968042576364
msgN :: 1
Data :: ~1427794575906:Ver:1427375441782463424515:IntelliJ_IDEA:IC-141.177:1.3.0:1.9.0-dev.10.10+2
''';
    var result = await runMap(data);
    expect(result, hasLength(1));
    expect(result[target.basic_info_key], [target.skip_value]);
  });

  test('map truncated', () async {
    var data = '''versionID :: 2015-02-04
sessionID :: PRI1427794575682.9546
ServerDate-b75e7a7f-dc90-48a1-8637-dbc123175a4d :: 2015-03-31 09:36:45
RandomToken-b75e7a7f-dc90-48a1-8637-dbc123175a4d :: 0.3968042576364
''';
    var result = await runMap(data);
    expect(result, hasLength(1));
    expect(result[target.basic_info_key], [target.unknown_value]);
  });

  test('map non-pri', () async {
    var data = '''sessionID :: 1427814186100.0976562500000
msgN :: 0
Data :: ~1427814186420:Noti:{"event"::"server.connected","params"::{"version"::"1.5.0"}}
~1427814186458:Req:{"id"::"0","method"::"server.getVersion","clientRequestTime"::1427814185389}
~1427814186476:Res:{"id"::"0","result"::{"version"::"1.5.0"}}
~1427814186484:Req:{"id"::"1","method"::"server.setSubscriptions","params"::{"subscriptions"::["STATUS"]},"clientRequestTime"::1427814185409}
~1427814186490:Res:{"id"::"1"}
''';
    var result = await runMap(data);
    expect(result, hasLength(1));
    expect(result[target.basic_info_key], [target.skip_value]);
  });
}

Future<Map<String, List<String>>> runMap(String data) async {
  StreamController<String> controller = new StreamController();
  controller.add(data);
  controller.close();
  String logKey = 'path/to/some/log/file';
  return target.mapStream(logKey, controller.stream.transform(new LineSplitter()));
}
