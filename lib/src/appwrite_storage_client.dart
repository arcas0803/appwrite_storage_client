import 'package:appwrite_storage_client/src/preview_output_format.dart';
import 'package:common_classes/common_classes.dart';

/// Base class for all Appwrite storage clients
///
abstract class AppwriteStorageClient {
  /// Creates a new file.
  ///
  /// [fileId] Unique file ID.
  ///
  /// [path] File path.
  ///
  /// On Success, returns the url of the created file.
  ///
  /// On Failure, returns an [AppwriteStorageFailure].
  ///
  Future<Result<String>> createImage({
    required String fileId,
    required String path,
  });

  /// Get file for the given [fileId].
  ///
  /// On Success, returns the url of the file.
  ///
  /// On Failure, returns an [AppwriteStorageFailure].
  ///
  String getImageUrl({
    required String fileId,
  });

  /// Get file preview for the given [fileId].
  ///
  /// [width] Width of the thumbnail in pixels.
  ///
  /// [height] Height of the thumbnail in pixels.
  ///
  /// [quality] Quality of the thumbnail between 0 and 100.
  ///
  /// [format] Output format of the thumbnail. Possible values are png, jpeg, and webp.
  ///
  /// On Success, returns the url of the file preview url.
  ///
  /// On Failure, returns an [AppwriteStorageFailure].
  ///
  String getImagePreviewUrl({
    required String fileId,
    int? width,
    int? height,
    int? quality,
    PreviewOutputFormat? format,
  });

  /// Get file for the given [fileId].
  ///
  /// On Failure, returns an [AppwriteStorageFailure].
  ///
  Future<Result<void>> deleteImage({
    required String fileId,
  });

  /// Get file for the given [fileId].
  ///
  /// [fileId] Unique file ID.
  ///
  /// [path] File path.
  ///
  /// On Success, returns the url of the updated file.
  ///
  /// On Failure, returns an [AppwriteStorageFailure].
  ///
  Future<Result<String>> updateImage({
    required String fileId,
    required String path,
  });

  /// Create files
  ///
  /// Given a list of tuples of [fileId] and [path], creates the files.
  ///
  /// On Success, returns a list of urls of the created files.
  ///
  /// On Failure, returns an [AppwriteStorageFailure].
  ///
  Future<Result<List<String>>> createImages({
    required List<
            ({
              String fileId,
              String path,
            })>
        files,
  });

  /// Remove files
  ///
  ///
  /// Given a list of [fileIds], removes the files.
  ///
  /// On Success, returns a list of urls of the removed files.
  ///
  /// On Failure, returns an [AppwriteStorageFailure].
  ///
  Future<Result<void>> deleteImages({
    required List<String> fileIds,
  });

  /// Get file id from url
  ///
  /// Given a [url], returns the file id.
  ///
  /// On Success, returns the file id.
  ///
  /// On Failure, returns an [AppwriteStorageFailure].
  ///
  String getImageIdFromUrl({
    required String url,
  });
}
