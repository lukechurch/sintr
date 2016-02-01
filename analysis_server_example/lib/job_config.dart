// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'query.dart';
import 'query/versions.dart';
import 'query/severe_log.dart';


class JobConfig {
  final String jobName;
  final String filter;
  final Mapper mapper;
  final needsSessionInfo;
  const JobConfig(this.jobName, this.filter, this.mapper, this.needsSessionInfo);
}

final versionsJob = new JobConfig(
  "versionMetrics",
  "PRI",
  new VersionMapper(),
  false
);

final severeLogsAll = new JobConfig(
  "SevereLogsAll",
  "!PRI",
  new SevereLogMapper(),
  true
);

final jobMap = <String, JobConfig>{
  'versions' : versionsJob,
  'severeLogs' : severeLogsAll
};

final DEFAULT = versionsJob;
