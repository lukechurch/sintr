# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Deploy cluster of sintr workers

WORKER_NAME_BASE="sintr-worker-uscc-"

echo "Destroying USSC"

for i in `seq 1 10`;
do
    WORKER_NAME=$WORKER_NAME_BASE$i
    echo "Deleting " $WORKER_NAME
    gcloud compute -q --project "liftoff-dev" instances delete $WORKER_NAME --zone "us-central1-c" &
done

wait

WORKER_NAME_BASE="sintr-worker-useb-"

echo "Destroying USEB"

for i in `seq 1 10`;
do
    WORKER_NAME=$WORKER_NAME_BASE$i
    echo "Deleting " $WORKER_NAME
    gcloud compute -q --project "liftoff-dev" instances delete $WORKER_NAME --zone "us-east1-b" &
done

wait

echo "Destroying completed"
echo "Cluster shutdown complete"
