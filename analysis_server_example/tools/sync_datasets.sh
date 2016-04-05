# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Syncs the datasets commonly in use by sintr_analysis_server_example
gsutil -m cp -n gs://dart-analysis-server-sessions-sorted/compressed/* \
    gs://liftoff-dev-datasources-analysis-server-sessions-sorted
