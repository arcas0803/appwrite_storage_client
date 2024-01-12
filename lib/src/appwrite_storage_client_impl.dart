import 'dart:async';
import 'dart:io' as io;

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:appwrite_storage_client/src/appwrite_storage_client.dart';
import 'package:appwrite_storage_client/src/appwrite_storage_failure.dart';
import 'package:appwrite_storage_client/src/preview_output_format.dart';
import 'package:appwrite_storage_client/src/utils.dart';
import 'package:common_classes/common_classes.dart';
import 'package:connectivity_client/connectivity_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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

  bool _isImage({required String path}) {
    _logger?.d('Checking if file is image with path: $path');

    final fileExtension = path.split('.').last.toLowerCase();
    return switch (fileExtension) {
      'jpg' => true,
      'jpeg' => true,
      'png' => true,
      'webp' => true,
      'heic' => true,
      _ => false,
    };
  }

  Future<String> _compressImage({
    required String path,
    required String fileId,
  }) async {
    _logger?.d('Compressing image with id: $fileId');

    try {
      // Divide la ruta original en directorios
      List<String> pathSegments = path.split('/');

      // Reemplaza el último elemento (nombre del archivo original) con el nuevo nombre del archivo
      pathSegments[pathSegments.length - 1] = '$fileId.jpg';

      // Une los segmentos de la ruta de nuevo en una sola cadena
      String newPath = pathSegments.join('/');

      var result = await FlutterImageCompress.compressAndGetFile(
        path,
        newPath,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        final failure = ImageCompressionFailure(
          error: 'Error compressing image',
          stackTrace: StackTrace.current,
        );

        _logger?.e(
          '[ERROR] Error compressing image with id: $fileId',
          time: DateTime.now(),
          error: failure,
          stackTrace: failure.stackTrace,
        );

        _telemetryOnError?.call(failure);

        return throw failure;
      }

      print(io.File(path).lengthSync());
      print(io.File(result.path).lengthSync());

      _logger?.d('Image compressed with id: $fileId');

      _telemetryOnSuccess?.call();

      return result.path;
    } catch (e, s) {
      final failure = ImageCompressionFailure(
        error: e.toString(),
        stackTrace: s,
      );

      _logger?.e(
        '[ERROR] Error compressing image with id: $fileId',
        time: DateTime.now(),
        error: failure,
        stackTrace: failure.stackTrace,
      );

      return throw failure;
    }
  }

  Future<File> _uploadImage(UploadImageParams params) async {
    final result = await _storage.createFile(
      bucketId: params.bucketId,
      fileId: params.fileId,
      file: InputFile.fromPath(path: params.path),
    );

    return result;
  }

  @override
  Future<Result<String>> createImage(
      {required String fileId, required String path}) async {
    _logger?.d('Creating file with id: $fileId');

    _logger?.d('Checking if file is image with path: $path');

    if (!_isImage(path: path)) {
      return Result.error(
        FormatFailure(
          error:
              'File is not an image. Only jpg, jpeg, png, webp and heic are supported. The file has an extension of ${path.split('.').last}',
          stackTrace: StackTrace.current,
        ),
      );
    }

    final connectivityResult =
        await _connectivityClient.checkInternetConnection();

    if (connectivityResult is Error) {
      return Result.error(
        NoInternetConnectionFailure(),
      );
    }

    return Result.asyncGuard(
      () async {
        final compressResult = await _compressImage(
          path: path,
          fileId: fileId,
        );

        final compressPath = (compressResult as Success<String>).value;

        final result = await compute(
          _uploadImage,
          UploadImageParams(
            bucketId: _bucketId,
            fileId: fileId,
            path: compressPath,
          ),
        );

        _logger?.d('File created with id: ${result.$id}');

        final url = getImageUrl(fileId: result.$id);

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
  Future<Result<List<String>>> createImages(
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
                return getImageUrl(fileId: value.$id);
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
  Future<Result<void>> deleteImage({required String fileId}) async {
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
  Future<Result<void>> deleteImages({required List<String> fileIds}) async {
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
  String getImagePreviewUrl(
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
  String getImageUrl({required String fileId}) {
    _logger?.d('Getting file url for file with id: $fileId');

    final url =
        '${_storage.client.endPoint}/storage/buckets/$_bucketId/files/$fileId';

    _logger?.d('File url: $url');

    _telemetryOnSuccess?.call();

    return url;
  }

  @override
  Future<Result<String>> updateImage(
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

        return getImageUrl(fileId: result.$id);
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
  Result<String> getImageIdFromUrl({required String url}) {
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
