
# Run this from the Sintr root
if [ "$#" -ne 1 ]; then
    echo "Usage: batch_execute CLUSTER_SIZE"
    exit
fi

CLUSTER_SIZE=$1

echo "Syncing datasets"
# ./analysis_server_example/tools/sync_datasets.sh
# ./analysis_server_example/tools/compact_datasets.sh

echo "Starting run"

echo "Delete logs"
gsutil -m rm gs://liftoff-dev-worker-logs/*

echo "Deleting tasks"
dart analysis_server_example/bin/delete_all_tasks.dart

echo "Deploying Sintr"
./tools/scripts/deploy_image.sh
gsutil cp tools/scripts/worker_startup.sh gs://liftoff-dev-source/worker_startup.sh

echo "Deploying Client code"
dart ~/GitRepos/sintr_common/bin/uploadSource.dart liftoff-dev \
  liftoff-dev-source test_worker.json ~/GitRepos/sintr/analysis_server_example

echo " ======= MAPPER PHASE ======= "

echo " ----- VERSIONS ----- "

echo "Creating tasks"
dart analysis_server_example/bin/create_tasks.dart versions true

echo "Deploying cluster"
./tools/scripts/deploy_worker_cluster.sh $CLUSTER_SIZE versions

echo "Starting monitoring loop"
dart analysis_server_example/bin/query_wait_for_done.dart --loop

echo "Cleanup"

echo "Deleting tasks"
dart analysis_server_example/bin/delete_all_tasks.dart

echo "Deleting cluster"
./tools/scripts/delete_cluster.sh $CLUSTER_SIZE

echo " ----- EXCEPTION CLUSTERS ----- "

echo "Creating tasks"
dart analysis_server_example/bin/create_tasks.dart severeLogs true

echo "Deploying cluster"
./tools/scripts/deploy_worker_cluster.sh $CLUSTER_SIZE severeLogs

echo "Starting monitoring loop"
dart analysis_server_example/bin/query_wait_for_done.dart --loop

echo "Cleanup"

echo "Deleting tasks"
dart analysis_server_example/bin/delete_all_tasks.dart

echo "Deleting cluster"
./tools/scripts/delete_cluster.sh $CLUSTER_SIZE

echo " ======= REDUCER PHASE ======= "

echo "Copying data to local"

mkdir -p ~/Analysis/AnalysisServer/versions
mkdir -p ~/Analysis/AnalysisServer/severeCount
mkdir -p ~/Analysis/AnalysisServer/severeLogs
mkdir -p ~/Analysis/AnalysisServer/exceptionClusters

gsutil -m cp -n gs://liftoff-dev-results/versions/out/* ~/Analysis/AnalysisServer/versions
gsutil -m cp -n gs://liftoff-dev-results/severeCount/out/* ~/Analysis/AnalysisServer/severeCount
gsutil -m cp -n gs://liftoff-dev-results/severeLogs/out/* ~/Analysis/AnalysisServer/severeLogs

dart analysis_server_example/local_reducer_severeCount.dart \
  ~/Analysis/AnalysisServer/severeCount > ~/Analysis/AnalysisServer/analysisServerSevereCount.log

dart analysis_server_example/local_reducer_versions.dart \
  ~/Analysis/AnalysisServer/versions > ~/Analysis/AnalysisServer/analysisServerVersions.log

dart analysis_server_example/local_stacktrace_cluster.dart \
  ~/Analysis/AnalysisServer/severeLogs \
  ~/Analysis/AnalysisServer/exceptionClusters \
    > ~/Analysis/AnalysisServer/cluster_log.log
