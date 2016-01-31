# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Halt on the first error
set -e

JOB_NAME=$1
CLUSTER_SIZE=20

echo "Starting run for: " $JOB_NAME

# echo "Delete logs"
gsutil -m rm gs://liftoff-dev-worker-logs/*

echo "Deleting tasks"
dart z_sintr_analysis_server_example/bin/delete_all_tasks.dart

echo "Deploying Sintr"
./tools/scripts/deploy_image.sh
gsutil cp tools/scripts/worker_startup.sh gs://liftoff-dev-source/worker_startup.sh

echo "Deploying Client code"
z_sintr_code_analysis_example/tools/upload_src.sh

# The next part is slow and can be done in parrallel

echo "Deploying cluster"
./tools/scripts/deploy_worker_cluster.sh $CLUSTER_SIZE $JOB_NAME

echo "Creating tasks"
dart z_sintr_code_analysis_example/bin/create_tasks.dart

# echo "Starting monitoring loop"
dart z_sintr_code_analysis_example/bin/query_wait_for_done.dart --loop

# When we're here the job is done
echo "Deleting cluster"
# ./tools/scripts/delete_cluster.sh $CLUSTER_SIZE
