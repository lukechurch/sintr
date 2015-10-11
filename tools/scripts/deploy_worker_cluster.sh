# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Deploy cluster of sintr workers

WORKER_NAME_BASE="sintr-worker-"

for i in `seq 1 10`;
do
    WORKER_NAME=$WORKER_NAME_BASE$i
    echo "Starting " $WORKER_NAME
    gcloud compute --project "liftoff-dev" instances create $WORKER_NAME --zone "us-central1-c" --machine-type "n1-standard-1" --network "default" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/cloud-platform" --image "https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1404-trusty-v20150909a" --boot-disk-size "25" --boot-disk-type "pd-ssd" --boot-disk-device-name $WORKER_NAME
    gcloud compute --project "liftoff-dev" ssh --zone "us-central1-c" $WORKER_NAME 'gsutil cp gs://liftoff-dev-source/worker_startup.sh .; chmod +x worker_startup.sh; screen -d -m ./worker_startup.sh'
done
