// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_common.pubsub_utils;

import 'dart:async';

import 'package:gcloud/pubsub.dart';
import "package:logging/logging.dart" as logging;

final _log = new logging.Logger("PubSub_support");

/// Gets a topic, if it doesn't already exist, create it.
Future<Topic> getTopic(String name, PubSub ps) async {

  // Try and find the topic.
  _log.finer("PRE: Getting topic for $name");

  Topic topic;

  try {
    topic = await ps.lookupTopic(name);
  } catch (e, st) {
    _log.finer("NOK: Topic lookup failed");
    _log.finest(e);
    _log.finest(st);
  }

  if (topic != null) {
    _log.finer("OK: Existing topic found: $name");
    return topic;
  }

  // Try and create the topic.
  try {
    topic = await ps.createTopic(name);
  } catch (e, st) {
    _log.finer("NOK: Topic creation failed");
    _log.finest(e);
    _log.finest(st);
  }

  if (topic != null) {
    _log.fine("OK: Topic created: $name");
    return topic;
  }

  // The creation make have failed because of a race between the lookup and
  // the creation.
  try {
    topic = await ps.lookupTopic(name);
  } catch (e, st) {
    _log.finer("NOK: Topic lookup failed");
    _log.finest(e);
    _log.finest(st);
  }

  if (topic != null) {
    _log.finer("OK: Topic found after race: $name");
    return topic;
  }

  _log.shout("FAIL: Topic not $name");
  throw "Topic not found: $name";
}
