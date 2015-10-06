set -e

# Setup the test tasks
dart -c ../sintr_common/example/task_example.dart
echo "Tasks setup"

dart -c bin/startup.dart liftoff-dev example_task ../sintr_working/ 2&1> ../sintr_working/worker.log
