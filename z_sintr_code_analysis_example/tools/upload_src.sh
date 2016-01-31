# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Upload the sample source ready for execution
# Should be run from the sintr root folder
set -e

dart sintr_common/bin/uploadSource.dart liftoff-dev liftoff-dev-source test_worker.json ~/GitRepos/sintr/z_sintr_code_analysis_example
