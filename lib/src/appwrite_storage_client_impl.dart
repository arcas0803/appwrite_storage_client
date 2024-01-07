import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite_storage_client/src/appwrite_storage_client.dart';
import 'package:appwrite_storage_client/src/appwrite_storage_failure.dart';
import 'package:appwrite_storage_client/src/preview_output_format.dart';
import 'package:common_classes/common_classes.dart';
import 'package:connectivity_client/connectivity_client.dart';
import 'package:logger/logger.dart';

/// Implementation of [AppwriteStorageClient] that uses [appwrite] to communicate with
/// the server.
///
class AppwriteStorageClientImpl implements AppwriteStorageClient {
  final ConnectivityClient _connectivityClient;

  final Logger? _logger;

  final FutureOr<void> Function(Failure)? _telemetryOnError;

  final FutureOr<void> Function()? _telemetryOnSuccess;

  final Storage _storage;

  final String _bucketId;

  AppwriteStorageClientImpl({
    required Storage storage,
    required String bucketId,
    Logger? logger,
    FutureOr<void> Function(Failure)? telemetryOnError,
    FutureOr<void> Function()? telemetryOnSuccess,
  })  : _connectivityClient = ConnectivityClientImpl(
          logger: logger,
          telemetryOnError: telemetryOnError,
          telemetryOnSuccess: telemetryOnSuccess,
        ),
        _logger = logger,
        _telemetryOnError = telemetryOnError,
        _telemetryOnSuccess = telemetryOnSuccess,
        _storage = storage,
        _bucketId = bucketId;

  @override
  Future<Result<String>> createFile(
      {required String fileId, required String path}) async {
    _logger?.d('Creating file with id: $fileId');

    final connectivityResult =
        await _connectivityClient.checkInternetConnection();

    if (connectivityResult is Error) {
      return Result.error(
        NoInternetConnectionFailure(),
      );
    }

    return Result.asyncGuard(
      () async {
        final result = await _storage.createFile(
          bucketId: _bucketId,
          fileId: fileId,
          file: InputFile.fromPath(path: path),
        );

        _logger?.d('File created with id: ${result.$id}');

        final url = getFileUrl(fileId: result.$id);

        _logger?.d('File url: $url');

        _telemetryOnSuccess?.call();

        return url;
      },
      onError: (e, s) {
        late Failure failure;

        if (e is AppwriteException) {
          if (e.code != null) {
            if (e.code == 401 || e.code == 403) {
              failure = NoPermissionsFailure(
                error: e.toString(),
                stackTrace: s,
              );
            } else {
              failure = UploadFileFailure(
                error: e.toString(),
                stackTrace: s,
              );
            }
          } else {
            failure = UploadFileFailure(
              error: e.toString(),
              stackTrace: s,
            );
          }
        } else {
          failure = UploadFileFailure(
            error: e.toString(),
            stackTrace: s,
          );
        }
        _logger?.e(
          '[ERROR] Error creating file: $fileId',
          time: DateTime.now(),
          error: e,
          stackTrace: s,
        );

        _telemetryOnError?.call(failure);

        return failure;
      },
    );
  }

  @override
  Future<Result<List<String>>> createFiles(
      {required List<({String fileId, String path})> files}) async {
    _logger?.d('[START] Creating files');

    final connectivityResult =
        await _connectivityClient.checkInternetConnection();

    if (connectivityResult is Error) {
      return Result.error(
        NoInternetConnectionFailure(),
      );
    }

    return Result.asyncGuard(
      () async {
        final result = await Future.wait(
          [
            for (final file in files)
              _storage
                  .createFile(
                bucketId: _bucketId,
                fileId: file.fileId,
                file: InputFile.fromPath(path: file.path),
              )
                  .then((value) {
                return getFileUrl(fileId: value.$id);
              })
          ],
          eagerError: true,
        );
        _logger?.d('[SUCESS] Files created');

        _telemetryOnSuccess?.call();

        return result;
      },
      onError: (e, s) {
        late Failure failure;

        if (e is AppwriteException) {
          if (e.code != null) {
            if (e.code == 401 || e.code == 403) {
              failure = NoPermissionsFailure(
                error: e.toString(),
                stackTrace: s,
              );
            } else {
              failure = UploadFileFailure(
                error: e.toString(),
                stackTrace: s,
              );
            }
          } else {
            failure = UploadFileFailure(
              error: e.toString(),
              stackTrace: s,
            );
          }
        } else {
          failure = UploadFileFailure(
            error: e.toString(),
            stackTrace: s,
          );
        }
        _logger?.e(
          '[ERROR] Error creating files',
          time: DateTime.now(),
          error: e,
          stackTrace: s,
        );

        _telemetryOnError?.call(failure);

        return failure;
      },
    );
  }

  @override
  Future<Result<void>> deleteFile({required String fileId}) async {
    _logger?.d('[START] Deleting file with id: $fileId');

    final connectivityResult =
        await _connectivityClient.checkInternetConnection();

    if (connectivityResult is Error) {
      return Result.error(
        NoInternetConnectionFailure(),
      );
    }

    return Result.asyncGuard(
      () async {
        await _storage.deleteFile(
          fileId: fileId,
          bucketId: _bucketId,
        );

        _logger?.d('[SUCESS] File deleted with id: $fileId');

        _telemetryOnSuccess?.call();
      },
      onError: (e, s) {
        late Failure failure;

        if (e is AppwriteException) {
          if (e.code != null) {
            if (e.code == 401 || e.code == 403) {
              failure = NoPermissionsFailure(
                error: e.toString(),
                stackTrace: s,
              );
            } else {
              failure = RemoveFileFailure(
                error: e.toString(),
                stackTrace: s,
              );
            }
          } else {
            failure = RemoveFileFailure(
              error: e.toString(),
              stackTrace: s,
            );
          }
        } else {
          failure = RemoveFileFailure(
            error: e.toString(),
            stackTrace: s,
          );
        }
        _logger?.e(
          '[ERROR] Error removing file: $fileId',
          time: DateTime.now(),
          error: e,
          stackTrace: s,
        );

        _telemetryOnError?.call(failure);

        return failure;
      },
    );
  }

  @override
  Future<Result<void>> deleteFiles({required List<String> fileIds}) async {
    _logger?.d('[START] Deleting files');

    final connectivityResult =
        await _connectivityClient.checkInternetConnection();

    if (connectivityResult is Error) {
      return Result.error(
        NoInternetConnectionFailure(),
      );
    }

    return Result.asyncGuard(
      () async {
        await Future.wait(
          [
            for (final fileId in fileIds)
              _storage.deleteFile(
                fileId: fileId,
                bucketId: _bucketId,
              )
          ],
          eagerError: true,
        );

        _logger?.d('[SUCESS] Files deleted');

        _telemetryOnSuccess?.call();
      },
      onError: (e, s) {
        late Failure failure;

        if (e is AppwriteException) {
          if (e.code != null) {
            if (e.code == 401 || e.code == 403) {
              failure = NoPermissionsFailure(
                error: e.toString(),
                stackTrace: s,
              );
            } else {
              failure = RemoveFileFailure(
                error: e.toString(),
                stackTrace: s,
              );
            }
          } else {
            failure = RemoveFileFailure(
              error: e.toString(),
              stackTrace: s,
            );
          }
        } else {
          failure = RemoveFileFailure(
            error: e.toString(),
            stackTrace: s,
          );
        }
        _logger?.e(
          '[ERROR] Error removing files',
          time: DateTime.now(),
          error: e,
          stackTrace: s,
        );

        _telemetryOnError?.call(failure);

        return failure;
      },
    );
  }

  @override
  String getFilePreviewUrl(
      {required String fileId,
      int? width,
      int? height,
      int? quality,
      PreviewOutputFormat? format}) {
    _logger?.d('Getting file preview url for file with id: $fileId');

    final queries = <String>[];

    if (width != null) {
      queries.add('width=$width');
    }

    if (height != null) {
      queries.add('height=$height');
    }

    if (quality != null) {
      queries.add('quality=$quality');
    }

    if (format != null) {
      queries.add('format=${format.value}');
    }

    final url =
        '${_storage.client.endPoint}/storage/buckets/$_bucketId/files/$fileId/preview?${queries.join('&')}';

    _logger?.d('File preview url: $url');

    _telemetryOnSuccess?.call();

    return url;
  }

  @override
  String getFileUrl({required String fileId}) {
    _logger?.d('Getting file url for file with id: $fileId');

    final url =
        '${_storage.client.endPoint}/storage/buckets/$_bucketId/files/$fileId';

    _logger?.d('File url: $url');

    _telemetryOnSuccess?.call();

    return url;
  }

  @override
  Future<Result<String>> updateFile(
      {required String fileId, required String path}) async {
    _logger?.d('[START] Updating file with id: $fileId');

    final connectivityResult =
        await _connectivityClient.checkInternetConnection();

    if (connectivityResult is Error) {
      return Result.error(
        NoInternetConnectionFailure(),
      );
    }

    return Result.asyncGuard(
      () async {
        await _storage.deleteFile(
          fileId: fileId,
          bucketId: _bucketId,
        );

        final result = await _storage.createFile(
          bucketId: _bucketId,
          fileId: fileId,
          file: InputFile.fromPath(path: path),
        );

        _logger?.d('[SUCESS] File updated with id: ${result.$id}');

        _telemetryOnSuccess?.call();

        return getFileUrl(fileId: result.$id);
      },
      onError: (e, s) {
        late Failure failure;

        if (e is AppwriteException) {
          if (e.code != null) {
            if (e.code == 401 || e.code == 403) {
              failure = NoPermissionsFailure(
                error: e.toString(),
                stackTrace: s,
              );
            } else {
              failure = UpdateFileFailure(
                error: e.toString(),
                stackTrace: s,
              );
            }
          } else {
            failure = UpdateFileFailure(
              error: e.toString(),
              stackTrace: s,
            );
          }
        } else {
          failure = UpdateFileFailure(
            error: e.toString(),
            stackTrace: s,
          );
        }
        _logger?.e(
          '[ERROR] Error removing file: $fileId',
          time: DateTime.now(),
          error: e,
          stackTrace: s,
        );

        _telemetryOnError?.call(failure);

        return failure;
      },
    );
  }

  @override
  Result<String> getFileIdFromUrl({required String url}) {
    _logger?.d('Getting file id from url: $url');

    if (url.contains(_storage.client.endPoint) == false) {
      final failure = InvalidUrlFileFailure(
        error: 'Invalid url file',
        stackTrace: StackTrace.current,
      );

      _logger?.e(
        '[ERROR] Error getting file id from url: $url',
        time: DateTime.now(),
        error: failure,
        stackTrace: failure.stackTrace,
      );
      _telemetryOnError?.call(failure);

      return Result.error(failure);
    }

    final uri = Uri.parse(url);

    final pathSegments = uri.pathSegments;

    if (pathSegments.length != 5) {
      final failure = InvalidUrlFileFailure(
        error: 'Invalid url file',
        stackTrace: StackTrace.current,
      );

      _logger?.e(
        '[ERROR] Error getting file id from url: $url',
        time: DateTime.now(),
        error: failure,
        stackTrace: failure.stackTrace,
      );

      _telemetryOnError?.call(failure);

      return Result.error(
        failure,
      );
    }

    _logger?.d('File id: ${pathSegments[3]}');

    _telemetryOnSuccess?.call();

    return Result.success(
      pathSegments[3],
    );
  }
}
