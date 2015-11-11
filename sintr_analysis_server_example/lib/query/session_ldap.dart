// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.session_ldap;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sintr_worker_lib/instrumentation_query.dart';
import 'package:sintr_worker_lib/query.dart';
import 'package:sintr_worker_lib/session_info.dart';

final sessionIdComparator = (String s1, String s2) =>
    double.parse(s1) - double.parse(s2);

/// Combine map results to produce a mapping of LDAP to list of sessions
final sessionLdapReducer = (String sessionId, String ldap, Map results) {
  List<String> userSessions = results.putIfAbsent(ldap, () => []);
  orderedInsert(userSessions, sessionId, sessionIdComparator);
  return results;
};

/// Combine multiple map results
final sessionLdapReductionMerge = (Map results1, Map results2) {
  Map newResults = {};
  results1.forEach((ldap, sessionIds1) {
    var sessionIds2 = results2[ldap];
    if (sessionIds2 == null) {
      newResults[ldap] = sessionIds1;
    } else {
      var newSessionIds = []..addAll(sessionIds1);
      for (String id in sessionIds2) {
        orderedInsert(newSessionIds, id, sessionIdComparator);
      }
      newResults[ldap] = newSessionIds;
    }
  });
  results2.forEach((ldap, sessionIds2) {
    var sessionIds1 = results1[ldap];
    if (sessionIds1 == null) {
      newResults[ldap] = sessionIds2;
    }
  });
  return newResults;
};

/// [CompletionMapper] processes session log messages and extracts
/// an LDAP for the current session.
class SessionLdapMapper extends InstrumentationMapper {

  @override
  void mapLogMessage(int time, String msgType, String logMessageText) {
    if (msgType != 'Req') return;
    String method = extractJsonValue(logMessageText, 'method');
    if (method != 'analysis.setAnalysisRoots') return;
    Map json = JSON.decode(logMessageText.replaceAll("::", ":"));
    Map params = json['params'];
    List includedPaths = params['included'];

    // Look for LDAP in the included paths
    for (String path in includedPaths) {
      // Linux
      if (path.indexOf('/usr/local/') != -1) {
        int start = path.indexOf('/home/');
        if (start != -1) {
          start += 6;
          int end = path.indexOf('/', start);
          if (end != -1) {
            addResult(sessionId, path.substring(start, end));
            isMapComplete = true;
            return;
          }
        }
      }

      // Mac OSX
      if (path.startsWith('/Users/')) {
        int start = 7;
        int end = path.indexOf('/', start);
        if (end != -1) {
          addResult(sessionId, path.substring(start, end));
          isMapComplete = true;
          return;
        }
      }
    }
  }
}
