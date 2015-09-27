// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:gcloud/pubsub.dart' as ps;
import "package:googleapis_auth/auth_io.dart";
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import "package:sintr_common/pubsub_utils.dart";
import "package:logging/logging.dart" as logging;

main() async {


  logging.Logger.root.level = logging.Level.FINER;
  logging.Logger.root.onRecord.listen((logging.LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });


  config.configuration = new config.Configuration("dart-mind",
  cryptoTokensLocation: "${config.userHomePath}/Communications/CryptoTokens");

  logging.hierarchicalLoggingEnabled = true;
  AuthClient client =  await getAuthedClient();

  var pubsub = new ps.PubSub(client, config.configuration.projectName);

  var topic = await getTopic("test_not_there_2", pubsub);
  print (topic);

  print ("Pubsubbed ok");

}
