# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Deploy cluster of sintr workers


# Deploy cluster of sintr workers

function deploy_cluster {
                    # $1 Worker base name
                    # $2 zone
                     WORKER_NAME_BASE=$1
                     ZONE=$2
                     NODE_COUNT_PER_ZONE=2

                     echo "Deploying nodes in $2"

                     for i in `seq 1 $NODE_COUNT_PER_ZONE`;
                     do
                         WORKER_NAME=$WORKER_NAME_BASE$i
                         echo "Deploying " $WORKER_NAME

                         gcloud compute --project "liftoff-dev" instances \
                          create $WORKER_NAME \
                          --zone $ZONE \
                          --machine-type "n1-standard-1" \
                          --network "default" \
                          --maintenance-policy "TERMINATE" \
                          --preemptible \
                          --scopes "https://www.googleapis.com/auth/cloud-platform" \
                          --image "https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1404-trusty-v20150909a" \
                          --boot-disk-size "10" \
                          --boot-disk-type "pd-ssd" \
                          --boot-disk-device-name $WORKER_NAME &
                     done
                     wait

                     echo "Nodes ready, initting"

                     for i in `seq 1 $NODE_COUNT_PER_ZONE`;
                     do
                         WORKER_NAME=$WORKER_NAME_BASE$i
                         echo "Init " $WORKER_NAME
                         gcloud compute --project "liftoff-dev" \
                          ssh --zone $ZONE $WORKER_NAME \
                          'gsutil cp gs://liftoff-dev-source/worker_startup.sh .; chmod +x worker_startup.sh; screen -d -m ./worker_startup.sh' &
                     done
                     wait

                     echo "Deployment complete"

                }

echo "Starting cluster"

deploy_cluster "sintr-worker-usc1c-" "us-central1-c"
deploy_cluster "sintr-worker-use1b-" "us-east1-b"
# deploy_cluster "sintr-worker-usc2a-" "us-central2-a"

echo "Cluster start complete"
