import 'dart:async';
import 'dart:io' as io;

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:appwrite_storage_client/src/appwrite_storage_client.dart';
import 'package:appwrite_storage_client/src/appwrite_storage_failure.dart';
import 'package:appwrite_storage_client/src/preview_output_format.dart';
import 'package:common_classes/common_classes.dart';
import 'package:connectivity_client/connectivity_client.dart';
import 'package:flutter_avif/flutter_avif.dart';
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
  // Check if file is an image
  //
  // Returns true if the file is an image and false if not
  bool _isImage({required String path}) {
    _logger?.i('Checking if file is image with path: $path');

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

  // Compress an image using [FlutterImageCompress]
  //
  // Returns a [Result] with the path of the compressed image
  //
  // Throws an [ImageCompressionFailure] if the image can't be compressed
  //
  Future<Result<String>> _compressImage({
    required String path,
    required String fileId,
  }) async {
    _logger?.i('Compressing image with id: $fileId');

    try {
      // Divide la ruta original en directorios
      List<String> pathSegments = path.split('/');

      // Reemplaza el último elemento (nombre del archivo original) con el nuevo nombre del archivo
      pathSegments[pathSegments.length - 1] = '$fileId.avif';

      // Une los segmentos de la ruta de nuevo en una sola cadena
      String newPath = pathSegments.join('/');

      final inputFile = io.File(path);
      final inputBytes = await inputFile.readAsBytes();
      final avifBytes = await encodeAvif(inputBytes);
      final outputFile = io.File(newPath);
      await outputFile.writeAsBytes(avifBytes);

      /*
      var result = await FlutterImageCompress.compressAndGetFile(
        path,
        newPath,
        minHeight: 1920,
        minWidth: 1080,
        quality: 70,
        format: CompressFormat.webp,
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

        return Result.error(
          failure,
        );
      }*/

      _logger?.i('Image compressed with id: $fileId');
      _logger?.i('Original image size: ${io.File(path).lengthSync()}');
      _logger?.i('Compressed image size: ${io.File(newPath).lengthSync()}');

      _telemetryOnSuccess?.call();

      return Result.success(
        newPath,
      );
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

      return Result.error(
        failure,
      );
    }
  }

  Future<File> _uploadImage({
    required String fileId,
    required String path,
  }) async {
    final isImage = _isImage(path: path);

    if (!isImage) {
      throw FormatException(
        'File is not an image. Only jpg, jpeg, png, webp and heic are supported. The file has an extension of ${path.split('.').last}',
      );
    }

    final compressResult = await _compressImage(
      path: path,
      fileId: fileId,
    );

    late String finalPath;

    if (compressResult.isError) {
      finalPath = path;
    } else {
      finalPath = (compressResult as Success<String>).value;
    }

    _logger?.i('''
    Uploading image:
      - File id: $fileId
      - Path: $finalPath
      - Bucket id: $_bucketId
      - Size: ${io.File(finalPath).lengthSync()}
    ''');

    final result = await _storage.createFile(
      bucketId: _bucketId,
      fileId: fileId,
      file: InputFile.fromPath(
        path: finalPath,
      ),
    );

    return result;
  }

  @override
  Future<Result<String>> createImage(
      {required String fileId, required String path}) async {
    _logger?.i('Creating file with id: $fileId');

    final connectivityResult =
        await _connectivityClient.checkInternetConnection();

    if (connectivityResult is Error) {
      return Result.error(
        NoInternetConnectionFailure(),
      );
    }

    return Result.asyncGuard(
      () async {
        final result = await _uploadImage(
          fileId: fileId,
          path: path,
        );

        _logger?.i('File created with id: ${result.$id}');

        final url = getImageUrl(fileId: result.$id);

        _logger?.i('File url: $url');

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
    _logger?.i('[START] Creating files');

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
              _uploadImage(
                fileId: file.fileId,
                path: file.path,
              ).then(
                (value) {
                  return getImageUrl(fileId: value.$id);
                },
              )
          ],
          eagerError: true,
        );
        _logger?.i('[SUCESS] Files created');

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
    _logger?.i('[START] Deleting file with id: $fileId');

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

        _logger?.i('[SUCESS] File deleted with id: $fileId');

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
    _logger?.i('[START] Deleting files');

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

        _logger?.i('[SUCESS] Files deleted');

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
    _logger?.i('Getting file preview url for file with id: $fileId');

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

    _logger?.i('File preview url: $url');

    _telemetryOnSuccess?.call();

    return url;
  }

  @override
  String getImageUrl({required String fileId}) {
    _logger?.i('Getting file url for file with id: $fileId');

    final url =
        '${_storage.client.endPoint}/storage/buckets/$_bucketId/files/$fileId/view?project=${_storage.client.config['project']}';

    _logger?.i('File url: $url');

    _telemetryOnSuccess?.call();

    return url;
  }

  @override
  Future<Result<String>> updateImage(
      {required String fileId, required String path}) async {
    _logger?.i('[START] Updating file with id: $fileId');

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

        final result = await _uploadImage(
          fileId: fileId,
          path: path,
        );

        _logger?.i('[SUCESS] File updated with id: ${result.$id}');

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
    _logger?.i('Getting file id from url: $url');

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

    _logger?.i('File id: ${pathSegments[3]}');

    _telemetryOnSuccess?.call();

    return Result.success(
      pathSegments[3],
    );
  }
}
