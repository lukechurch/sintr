# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# dart ~/GitRepos/sintr_common/bin/uploadSource.dart liftoff-dev liftoff-dev-source test_worker.json ~/GitRepos/sintr/z_sintr_analysis_server_example


# Establish the root structure
rm -rf ~/src/sintr
mkdir -p ~/src/sintr
cd ~/src/sintr

# Deploy the image
gsutil cp gs://liftoff-dev-source/sintr-image.tar.gz ~/src/sintr/sintr-image.tar.gz
tar -xf sintr-image.tar.gz

# Remove any code in the working structure
rm -r ~/src/sintr/sintr_working
mkdir ~/src/sintr/sintr_working
cd ~/src/sintr/sintr_worker

# Startup the local worker
dart --observe=8283 -c bin/startup.dart liftoff-dev example_task ~/src/sintr/sintr_working/
