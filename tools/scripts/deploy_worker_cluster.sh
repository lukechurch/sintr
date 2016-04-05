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
                     NODE_COUNT_PER_ZONE=$3
                     JOB_NAME=$4

                     echo "Deploying nodes in $2"

                     for i in `seq 1 $NODE_COUNT_PER_ZONE`;
                     do
                         WORKER_NAME=$WORKER_NAME_BASE$i
                         echo "Deploying " $WORKER_NAME

                         gcloud compute --project "liftoff-dev" instances \
                          create $WORKER_NAME \
                          --zone $ZONE \
                          --machine-type "custom-1-6656" \
                          --network "default" \
                          --maintenance-policy "TERMINATE" \
                          --preemptible \
                          --scopes "https://www.googleapis.com/auth/cloud-platform" \
                          --image "https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1404-trusty-v20150909a" \
                          --boot-disk-size "10" \
                          --boot-disk-type "pd-standard" \
                          --boot-disk-device-name $WORKER_NAME &
                     done
                     wait

                     sleep 10

                     echo "Nodes ready, initting"

                     for i in `seq 1 $NODE_COUNT_PER_ZONE`;
                     do
                         WORKER_NAME=$WORKER_NAME_BASE$i
                         echo "Init " $WORKER_NAME
                         gcloud compute --project "liftoff-dev" \
                          ssh --zone $ZONE $WORKER_NAME \
                          "gsutil cp gs://liftoff-dev-source/worker_startup.sh .; chmod +x worker_startup.sh; screen -d -m ./worker_startup.sh $JOB_NAME" &
                     done
                     wait

                     echo "Deployment complete"

                }
if [ "$#" -ne 2 ]; then
    echo "Usage deploy_worker_cluster NODE_COUNT_PER_ZONE job_name"
    exit
fi

echo "Starting cluster of " $1 " for " $2

deploy_cluster "sintr-worker-usc1a-" "us-central1-a" $1 $2
deploy_cluster "sintr-worker-use1b-" "us-east1-b" $1 $2
deploy_cluster "sintr-worker-ase1a-" "asia-east1-a" $1 $2
deploy_cluster "sintr-worker-euw1b-" "europe-west1-b" $1 $2

echo "Cluster start complete"
