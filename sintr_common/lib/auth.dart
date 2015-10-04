// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_common.auth;

import 'dart:async';
import 'dart:io';

import 'package:gcloud/storage.dart';
import 'package:gcloud/pubsub.dart';
import 'package:gcloud/src/datastore_impl.dart' as datastore_impl;
import "package:googleapis_auth/auth_io.dart";
import "package:sintr_common/logging_utils.dart" as logging;

import "configuration.dart" as config;

/// Get an authenticated client either from the metadata server or a local key
Future<AuthClient> getAuthedClient() async {
  AuthClient client;

/*
  client = await _tryAuthViaMetadata();
  if (client != null) {
    logging.trace("OK: Client acquired from metadata server");
    return new Future.value(client);
  }
*/
  client = await _tryAuthViaCryptoToken();
  if (client != null) {
    logging.trace("OK: Client acquired from crypto token");
    return new Future.value(client);
  }

  logging.alert("FAIL: Unable to get client");
  throw "Unable to get client";
}

Future<AuthClient> _tryAuthViaMetadata() async {
  AuthClient client;
  try {
    logging.trace("PRE: About to get client from Metadata server");
    client = await clientViaMetadataServer();
  } catch (e, st) {
    logging.info("NOK: Metadata server query for client failed");
    logging.debug("$e");
    logging.debug("$st");
    return null;
  }
  return client;
}

Future<AuthClient> _tryAuthViaCryptoToken() async {
  AuthClient client;
  try {
    // Get an HTTP authenticated client using the service account credentials.
    var scopes = []
      ..addAll(datastore_impl.DatastoreImpl.SCOPES)
      ..addAll(Storage.SCOPES)
      ..addAll(PubSub.SCOPES);

    logging.trace("PRE: About to get client from Crypto Token");
    if (config.configuration == null ||
        config.configuration.cryptoTokensLocation == null) {
      print("NOK: No crypto token configuration");
      return null;
    }

    String cryptoPath = "${config.configuration.cryptoTokensLocation}/"
        "${config.configuration.projectName}.json";

    if (!(new File(cryptoPath).existsSync())) {
      logging.info("NOK: No cryptoToken at $cryptoPath");
      return null;
    }

    var jsonCredentials = new File(cryptoPath).readAsStringSync();
    var credentials = new ServiceAccountCredentials.fromJson(jsonCredentials);
    client = await clientViaServiceAccount(credentials, scopes);
  } catch (e, st) {
    logging.info("NOK: Crypto token from token failed");
    logging.debug(e);
    logging.debug("$st");
  }

  return client;
}
