
# Halt on the first error
set -e

JOB_NAME=$1
CLUSTER_SIZE=5

echo "Deleting tasks"
dart sintr_analysis_server_example/bin/delete_all_tasks.dart

echo "Deploying Sintr"
./tools/scripts/deploy_image.sh

echo "Deploying Client code"
./tools/scripts/upload_sample_src.sh

# The next part is slow and can be done in parrallel

echo "Deploying cluster"
./tools/scripts/deploy_worker_cluster.sh $CLUSTER_SIZE &

echo "Creating tasks"
dart sintr_analysis_server_example/bin/create_tasks.dart true $1

echo "Starting monitoring loop"
dart sintr_analysis_server_example/bin/query.dart --loop


# When we're here the job is done
echo "Deleting cluster"
./tools/scripts/delete_cluster.sh $CLUSTER_SIZE
