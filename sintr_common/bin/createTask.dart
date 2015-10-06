import 'package:gcloud/db.dart' as db;
import 'package:gcloud/service_scope.dart' as ss;
import 'package:gcloud/src/datastore_impl.dart' as datastore_impl;
import 'package:sintr_common/auth.dart';
import "package:sintr_common/configuration.dart" as config;
import 'package:sintr_common/logging_utils.dart';
import 'package:sintr_common/tasks.dart' as tasks;
import "package:sintr_common/gae_utils.dart" as gae_utils;


main() async {
  setupLogging();

  // String projectId = "sintr";
  String projectId = "liftoff-dev";

  config.configuration = new config.Configuration(projectId,
      cryptoTokensLocation: "/Users/lukechurch/Communications/CryptoTokens");

  var client = await getAuthedClient();

  var datastore = new datastore_impl.DatastoreImpl(client, 's~$projectId');
  var datastoreDB = new db.DatastoreDB(datastore);

  ss.fork(() async {


    db.registerDbService(datastoreDB);
    // db.DatastoreDB _db = ae.context.services.db;

    tasks.TaskController taskController =
        new tasks.TaskController("test_task");

    taskController.createTasks([
      new gae_utils.CloudStorageLocation("t1", "o1"),
      new gae_utils.CloudStorageLocation("t2", "o2")
    ], new gae_utils.CloudStorageLocation("liftoff-dev-source", "test_worker.json"),
    "liftoff-dev-results");
  });
}
