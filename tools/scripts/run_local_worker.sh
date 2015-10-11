# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Run sintr worker locally

rm -r ~/sintr_worker_folder
mkdir ~/sintr_worker_folder
cp sintr_analysis_server_example/pubspec.yaml ~/sintr_worker_folder
CURRENT_WORKING=`pwd`
cd sintr_common
SINTR_COMMON=`pwd`
cd ~/sintr_worker_folder
sed "s|\.\./sintr_common|$SINTR_COMMON|g" pubspec.yaml > pubspec.new
mv pubspec.yaml pubspec.old
mv pubspec.new pubspec.yaml
pub get
cd $CURRENT_WORKING
dart -c sintr_worker/bin/startup.dart liftoff-dev example_task ~/sintr_worker_folder/
