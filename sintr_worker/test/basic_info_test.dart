// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:sintr_worker/basic_info.dart' as basic_info;
import 'package:test/test.dart';

main() async {
  group('map', () {
    test('pri 0', () async {
      var data = '''versionID :: 2015-02-04
some random lines here
msgN :: 0
Data :: ~1427794575906:Ver:1427375441782463424515:IntelliJ_IDEA:IC-141.177:1.3.0:1.9.0-dev.10.10+2
''';
      var result = await runMap(data);
      expect(result, hasLength(1));
      var expectedKey = '${basic_info.key_prefix}2015-03-31';
      expect(result.keys.toList(), [expectedKey]);
      expect(result[expectedKey], [
        '1427375441782463424515:IntelliJ_IDEA:IC-141.177:1.3.0:1.9.0-dev.10.10+2'
      ]);
    });

    test('pri 1', () async {
      var data = '''versionID :: 2015-02-04
sessionID :: PRI1427794575682.9546
ServerDate-b75e7a7f-dc90-48a1-8637-dbc123175a4d :: 2015-03-31 09:36:45
RandomToken-b75e7a7f-dc90-48a1-8637-dbc123175a4d :: 0.3968042576364
msgN :: 1
Data :: ~1427794575906:Ver:1427375441782463424515:IntelliJ_IDEA:IC-141.177:1.3.0:1.9.0-dev.10.10+2
''';
      var result = await runMap(data);
      expect(result, hasLength(0));
    });

    test('truncated', () async {
      var data = '''versionID :: 2015-02-04
sessionID :: PRI1427794575682.9546
ServerDate-b75e7a7f-dc90-48a1-8637-dbc123175a4d :: 2015-03-31 09:36:45
RandomToken-b75e7a7f-dc90-48a1-8637-dbc123175a4d :: 0.3968042576364
''';
      var result = await runMap(data);
      expect(result, hasLength(1));
      expect(result[basic_info.key_prefix], [basic_info.unknown_value]);
    });

    test('non-pri', () async {
      var data = '''sessionID :: 1427814186100.0976562500000
msgN :: 0
Data :: ~1427814186420:Noti:{"event"::"server.connected","params"::{"version"::"1.5.0"}}
~1427814186458:Req:{"id"::"0","method"::"server.getVersion","clientRequestTime"::1427814185389}
~1427814186476:Res:{"id"::"0","result"::{"version"::"1.5.0"}}
~1427814186484:Req:{"id"::"1","method"::"server.setSubscriptions","params"::{"subscriptions"::["STATUS"]},"clientRequestTime"::1427814185409}
~1427814186490:Res:{"id"::"1"}
''';
      var result = await runMap(data);
      expect(result, hasLength(0));
    });
  });

  group('buildKey', () {
    test('1', () {
      expect(basic_info.buildKey('p', 123), 'p1969-12-31');
    });
    test('2', () {
      expect(basic_info.buildKey('pre', 1427814185389), 'pre2015-03-31');
    });
    test('3', () {
      expect(basic_info.buildKey('zo', 1418014765389), 'zo2014-12-07');
    });
  });

  test('reduce', () async {
    StreamController<String> controller = new StreamController();
    var uuid1 = '1427375441782463424515';
    var uuid2 = '1427375441739871424515';
    var data = '''$uuid1:IntelliJ_IDEA:IC-141.177:1.3.0:1.9.0-dev.10.10+1
$uuid1:IntelliJ_IDEA:IC-141.177:1.3.0:1.9.0-dev.10.10+2
$uuid1:IntelliJ_IDEA:IC-141.178:1.2.0:1.9.0-dev.10.10+2
$uuid2:IntelliJ_IDEA:IC-141.178:1.2.0:1.9.0-dev.10.10+2
$uuid2:dart.plugins:1.2.3:1.2.0:1.9.0-dev.10.10+2''';
    controller.add(data);
    controller.close();
    var result = await basic_info.reduce('basic_info_2015-03-31',
        controller.stream.transform(new LineSplitter()));
    // List of <clientId>:<clientVersion>:<numOfUsers>
    var clientInfo = result['clients_2015-03-31'];
    expect(clientInfo, contains('IntelliJ_IDEA:IC-141.177:1'));
    expect(clientInfo, contains('IntelliJ_IDEA:IC-141.178:2'));
    expect(clientInfo, contains('dart.plugins:1.2.3:1'));
    expect(clientInfo, hasLength(3));
    // List of <serverVersion>:<numOfUsers>
    var serverInfo = result['servers_2015-03-31'];
    expect(serverInfo, contains('1.3.0:1'));
    expect(serverInfo, contains('1.2.0:2'));
    expect(serverInfo, hasLength(2));
    // List of <sdkVersion>:<numOfUsers>
    var sdkInfo = result['sdks_2015-03-31'];
    expect(sdkInfo, contains('1.9.0-dev.10.10+2:2'));
    expect(sdkInfo, contains('1.9.0-dev.10.10+1:1'));
    expect(sdkInfo, hasLength(2));
  });
}

Future<Map<String, List<String>>> runMap(String data) async {
  StreamController<String> controller = new StreamController();
  controller.add(data);
  controller.close();
  String logKey = 'path/to/some/log/file';
  return basic_info.mapStream(
      logKey, controller.stream.transform(new LineSplitter()));
}
