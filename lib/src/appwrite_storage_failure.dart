import 'package:common_classes/common_classes.dart';

sealed class AppwriteStorageFailure extends Failure {
  AppwriteStorageFailure(
      {required super.message,
      required super.error,
      required super.stackTrace});
}

final class NoPermissionsFailure extends AppwriteStorageFailure {
  NoPermissionsFailure({
    required String error,
    required StackTrace stackTrace,
  }) : super(
          message: 'User does not have permissions to perform the operation',
          error: error,
          stackTrace: stackTrace,
        );
}

final class UploadFileFailure extends AppwriteStorageFailure {
  UploadFileFailure({
    required String error,
    required StackTrace stackTrace,
  }) : super(
          message: 'Error uploading file',
          error: error,
          stackTrace: stackTrace,
        );
}

final class RemoveFileFailure extends AppwriteStorageFailure {
  RemoveFileFailure({
    required String error,
    required StackTrace stackTrace,
  }) : super(
          message: 'Error removing file',
          error: error,
          stackTrace: stackTrace,
        );
}

final class UpdateFileFailure extends AppwriteStorageFailure {
  UpdateFileFailure({
    required String error,
    required StackTrace stackTrace,
  }) : super(
          message: 'Error updating file',
          error: error,
          stackTrace: stackTrace,
        );
}

final class InvalidUrlFileFailure extends AppwriteStorageFailure {
  InvalidUrlFileFailure({
    required String error,
    required StackTrace stackTrace,
  }) : super(
          message: 'Invalid url file',
          error: error,
          stackTrace: stackTrace,
        );
}

final class ImageCompressionFailure extends AppwriteStorageFailure {
  ImageCompressionFailure({
    required String error,
    required StackTrace stackTrace,
  }) : super(
          message: 'Error compressing image',
          error: error,
          stackTrace: stackTrace,
        );
}

final class FormatFailure extends AppwriteStorageFailure {
  FormatFailure({
    required String error,
    required StackTrace stackTrace,
  }) : super(
          message: 'Error formatting file',
          error: error,
          stackTrace: stackTrace,
        );
}

final class ServerFailure extends AppwriteStorageFailure {
  ServerFailure({
    required String error,
    required StackTrace stackTrace,
  }) : super(
          message: 'Server error',
          error: error,
          stackTrace: stackTrace,
        );
}
