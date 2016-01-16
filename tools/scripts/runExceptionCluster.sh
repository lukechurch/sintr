gsutil -m cp -n  gs://dart-analysis-server-sessions-sorted/compressed/* gs://liftoff-dev-datasources-analysis-server-sessions-sorted
./tools/scripts/run.sh SevereLogsAll
gsutil cp -n gs://liftoff-dev-results/SevereLogsAll/out/*  /Users/lukechurch/Analysis/AnalysisServer/SevereLogsAll
dart sintr_analysis_server_example/local_stacktrace_cluster.dart /Users/lukechurch/Analysis/AnalysisServer/SevereLogsAll /Users/lukechurch/Analysis/AnalysisServer/exceptionsClustersUnique > /Users/lukechurch/Analysis/AnalysisServer/exceptionsClusters/exceptionClusterUnique.log
