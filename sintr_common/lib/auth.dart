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
import "package:logging/logging.dart" as logging;

import "configuration.dart" as config;


final _log = new logging.Logger("Authentication");

/// Get an authenticated client either from the metadata server or a local key
Future<AuthClient> getAuthedClient() async {
  AuthClient client;

  client = await _tryAuthViaMetadata();
  if (client != null) {
    _log.finer("OK: Client acquired from metadata server");
    return new Future.value(client);
  }

  client = await _tryAuthViaCryptoToken();
  if (client != null) {
    _log.finer("OK: Client acquired from crypto token");
    return new Future.value(client);
  }

  _log.shout("FAIL: Unable to get client");
  throw "Unable to get client";
}

Future<AuthClient> _tryAuthViaMetadata() async {
  AuthClient client;
  try {
    _log.finer("PRE: About to get client from Metadata server");
    client = await clientViaMetadataServer();
  } catch (e, st) {
    _log.finer("NOK: Metadata server query for client failed");
    _log.finest(e);
    _log.finest(st);
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

    _log.finer("PRE: About to get client from Crypto Token");
    if (config.configuration == null
    || config.configuration.cryptoTokensLocation == null) {
      _log.finer("NOK: No crypto token configuration");
      return null;
    }

    String cryptoPath =
    "${config.configuration.cryptoTokensLocation}/"
    "${config.configuration.projectName}.json";

    if (!(new File(cryptoPath).existsSync())) {
      _log.finer("NOK: No cryptoToken at $cryptoPath");
      return null;
    }

    var jsonCredentials = new File(cryptoPath).readAsStringSync();
    var credentials = new ServiceAccountCredentials.fromJson(jsonCredentials);
    client = await clientViaServiceAccount(credentials, scopes);
  } catch (e, st) {
    _log.finer("NOK: Crypto token from token failed");
    _log.finest(e);
    _log.finest(st);
  }

  return client;
}