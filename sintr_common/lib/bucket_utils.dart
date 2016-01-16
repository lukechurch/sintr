// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_common.bucket_util;

import 'dart:async';
import 'dart:io';

import 'package:gcloud/storage.dart' as storage;
import 'package:path/path.dart' as path;

import 'logging_utils.dart' as log;

const _DEBUG = false;
const _SHOW_PROGRESS = true;

final _TIMEOUT = new Duration(seconds: 600);

/// Download [fileName] from [srcBucket] into [fileName] in [localDir].
/// This overwrite any existing files with the same name in [localDir].
/// Return a [Future] that completes with the local file when the download
/// is complete.
Future<File> downloadFile(
    storage.Bucket srcBucket, String cloudFileName, Directory localDir,
    [String localFileName]) async {
  if (localFileName == null) localFileName = cloudFileName;

  var localFile = new File(path.join(localDir.path, localFileName));
  if (!localFile.existsSync()) localFile.createSync(recursive: true);
  localFile.deleteSync();
  log.info("download ${cloudFileName} to: ${localFile.path}");

  // Could not get this to work... application pauses, then silently exits.
  //  var sink = localFile.openWrite();
  //  return sink
  //      .addStream(srcBucket.read(fileName).timeout(_TIMEOUT))
  //      .then((_) => sink.close());

  var sink = localFile.openWrite();
  Future sinkDone =
      sink.done.catchError((e, st) => log.alert("Sink Caught error: $e\n$st"));

  int bytesCount = 0;
  StreamSubscription subscription = srcBucket.read(cloudFileName).listen(null);

  subscription.onData((bytes) {
    if (_DEBUG) print(' Download ${bytes.length} bytes');
    sink.add(bytes);

    // Flush each MB to disk before downloading more
    // to prevent all of memory being consumed when downloading large files
    bytesCount += bytes.length;
    if (bytesCount > 1024 * 1024) {
      if (_SHOW_PROGRESS) stdout.write(".");
      bytesCount = 0;
      if (_DEBUG) print(' Download pausing for flush');
      subscription.pause();
      sink.flush().then((_) {
        if (_DEBUG) print(' Download resuming');
        subscription.resume();
      });
    }
  });

  subscription.onError(
      (e, st) => log.alert("byteStream.onError Caught error: $e\n$st"));

  var downloadCompleter = new Completer();
  subscription.onDone(downloadCompleter.complete);
  await downloadCompleter.future;
  stdout.writeln();
  log.info("Downloader: downloadCompleter.future done");

  sink.close();
  await sinkDone;
  log.info("Downloader: sinkDone");

  var completer = new Completer();
  sink.close().then((_) {
    log.info("Downloader: sink.close.then");

    srcBucket.info(cloudFileName).then((storage.ObjectInfo info) {
      // Verify the MD5 signature
      if (_SHOW_PROGRESS) print("");
      var localMd5 = _openSslMd5(localFile);
      if (_DEBUG) print('  localMD5 ${localMd5}');
      var remoteMd5 = info.md5Hash;
      if (_DEBUG) print('  remoteMD5 ${remoteMd5}');
      if (!equalMd5(localMd5, remoteMd5)) {
        localFile.deleteSync();
        throw 'download failed $cloudFileName, '
            'local MD5 Hash: $localMd5, remote MD5 Hash: $remoteMd5';
      }
      log.info("Downloader: MD5 match for download of $cloudFileName");
      log.info("Downloader: Downloaded ${localFile.lengthSync()} bytes ok");
      completer.complete(localFile);
    });
  });
  return completer.future;
}

/// Upload [localFile] to an identically name file in [dstBucket].
/// This overwrites any existing file with the same name in [dstBucket].
/// Return a [Future] that completes when the files has been uploaded.
Future uploadFile(File localFile, storage.Bucket dstBucket,
    [String fileName]) async {
  if (fileName == null) fileName = path.basename(localFile.path);

  log.info("Uploader: upload ${localFile.path} to: $fileName");

  var sink = dstBucket.write(fileName);
  log.info("Uploader: sink opened");

  Future sinkDone =
      sink.done.catchError((e, st) => log.alert("Sink Caught error: $e\n$st"));

  int bytesCount = 0;
  Stream<List<int>> byteStream = localFile.openRead();
  log.info("Uploader: openRead completed");

  StreamSubscription subscription = byteStream.listen(null);
  subscription.onData((List<int> bytes) {
    // if (_DEBUG) print(' Upload ${bytes.length} bytes');
    sink.add(bytes);

    bytesCount += bytes.length;
    if (bytesCount > 1024 * 1024) {
      if (_SHOW_PROGRESS) stdout.write(".");
      bytesCount = 0;
      subscription.pause(new Future.delayed(new Duration(milliseconds: 200)));
    }
  });
  subscription.onError(
      (e, st) => log.alert("byteStream.onError Caught error: $e\n$st"));

  log.info("Uploader: About to wait on subscription");
  var uploadCompleter = new Completer();
  subscription.onDone(uploadCompleter.complete);
  await uploadCompleter.future;
  stdout.writeln();
  log.info("Uploader: uploadCompleter.future done");

  sink.close();
  await sinkDone;
  log.info("Uploader: sinkDone");

  var completer = new Completer();

  // await new Future.delayed(new Duration(milliseconds: 500));
  // if (_DEBUG) log("Delay complete");
  //
  // await sink.done;
  // if (_DEBUG) log("Sink done");

  await sink.close();
  log.info("Uploader: Sink closed");

  // sink.done.then((_) {
  if (_SHOW_PROGRESS) print("");
  dstBucket.info(fileName).then((storage.ObjectInfo info) {
    var localMd5 = _openSslMd5(localFile);
    if (_DEBUG) print('  localMD5 ${localMd5}');

    var remoteMd5 = info.md5Hash;
    if (_DEBUG) print('  remoteMD5 ${localMd5}');

    if (!equalMd5(localMd5, remoteMd5)) {
      dstBucket.delete(fileName);
      throw 'upload failed $fileName, '
          'local MD5 Hash: $localMd5, remote MD5 Hash: $remoteMd5';
    }
    log.info("Uploader: MD5 match for upload of $fileName");
    log.info("Uploader: Uploaded ${localFile.lengthSync()} bytes ok");

    completer.complete();
  });
  // });
  return completer.future;
}

/// Return `true` if the specified hashes are equal.
bool equalMd5(List<int> localMd5, List<int> remoteMd5) {
  if (localMd5.length != remoteMd5.length) return false;
  for (int index = localMd5.length - 1; index >= 0; --index) {
    if (localMd5[index] != remoteMd5[index]) return false;
  }
  return true;
}

List<int> _openSslMd5(File f) {
  String md5Result = Process.runSync('openssl', ['md5', f.path]).stdout;
  String md5Hash = md5Result.split('= ')[1].trim();
  // Translate as hex pairs -> bytes
  List<int> bytes = [];
  for (int i = 0; i < md5Hash.length; i += 2) {
    String pair = "${md5Hash.substring(i, i+2)}";
    bytes.add(int.parse(pair, radix: 16));
  }
  return bytes;
}
