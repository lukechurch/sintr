set -e

echo "Sync dart-usage to liftoff-dev"
gsutil -m cp -n gs://dart-analysis-server-sessions-sorted/compressed/* \
    gs://liftoff-dev-datasources-analysis-server-sessions-sorted

echo "Backup"
gsutil -m cp -n -r gs://dart-analysis-server-sessions-sorted \
  gs://dart-analysis-server-sessions-sorted-backup

echo "Sync to archive"
gsutil -m cp -n -r gs://dart-analysis-server-sessions-sorted \
  gs://dart-analysis-server-sessions-sorted-archive

gsutil -m cp -n -r gs://liftoff-dev-datasources-analysis-server-sessions-sorted/* \
  gs://liftoff-dev-datasources-archive-dra/liftoff-dev-datasources/analysis-server-sessions

gsutil -m cp -n -r gs://liftoff-dev-results \
  gs://liftoff-dev-results-archive

echo "Delete files in the incoming buckets that are older than 45 days"

dart bin/delete_older_than.dart dart-usage dart-analysis-server-sessions-sorted 45
dart bin/delete_older_than.dart liftoff-dev liftoff-dev-datasources-analysis-server-sessions-sorted 45

echo "Delete old results"

dart bin/delete_older_than.dart liftoff-dev liftoff-dev-results 45
