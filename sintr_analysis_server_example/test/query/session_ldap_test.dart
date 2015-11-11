// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.session_ldap.test;

import 'package:sintr_worker_lib/query/session_ldap.dart';
import 'package:test/test.dart';

main() {
  test('sessionLdapReducer', () {
    Map<String, List<String>> results = {};

    results = sessionLdapReducer('142.1', 'ldap1', results);
    expect(results, hasLength(1));
    _expectSessions(results['ldap1'], ['142.1']);

    results = sessionLdapReducer('142.2', 'ldap1', results);
    expect(results, hasLength(1));
    _expectSessions(results['ldap1'], ['142.1', '142.2']);

    results = sessionLdapReducer('140.1', 'ldap1', results);
    expect(results, hasLength(1));
    _expectSessions(results['ldap1'], ['140.1', '142.1', '142.2']);

    results = sessionLdapReducer('132.1', 'ldap2', results);
    expect(results, hasLength(2));
    _expectSessions(results['ldap1'], ['140.1', '142.1', '142.2']);
    _expectSessions(results['ldap2'], ['132.1']);
  });

  test('sessionLdapReductionMerge', () {
    Map<String, List<String>> results1 = {
      'ldap1': ['142.1'],
      'ldap2': ['132.1'],
    };
    Map<String, List<String>> results2 = {
      'ldap1': ['140.1', '142.2'],
      'ldap3': ['186.1'],
    };

    var results = sessionLdapReductionMerge(results1, results2);
    expect(results, hasLength(3));
    _expectSessions(results['ldap1'], ['140.1', '142.1', '142.2']);
    _expectSessions(results['ldap2'], ['132.1']);
    _expectSessions(results['ldap3'], ['186.1']);
  });
}

_expectSessions(List<String> actualSessions, List<String> expectedSessions) {
  if (actualSessions.length == expectedSessions.length) {
    bool equal = true;
    for (int index = 0; index < actualSessions.length; ++index) {
      if (actualSessions[index] != expectedSessions[index]) {
        equal = false;
        break;
      }
    }
    if (equal) return;
  }
  fail('Expected  $expectedSessions\nbut found $actualSessions');
}
