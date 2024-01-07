import 'package:appwrite_storage_client/localization/appwrite_storage_localizations.dart';
import 'package:appwrite_storage_client/src/appwrite_storage_failure.dart';
import 'package:flutter/widgets.dart';

class AppwriteFailureUtil {
  static String getFailureNameUI({
    required BuildContext context,
    required AppwriteStorageFailure failure,
  }) {
    switch (failure) {
      case NoPermissionsFailure():
        return AppwriteStorageLocalizations.of(context)!.noPermissionFailure;
      case UploadFileFailure():
        return AppwriteStorageLocalizations.of(context)!.uploadFileFailure;
      case RemoveFileFailure():
        return AppwriteStorageLocalizations.of(context)!.removeFileFailure;
      case UpdateFileFailure():
        return AppwriteStorageLocalizations.of(context)!.updateFileFailure;
      case InvalidUrlFileFailure():
        return AppwriteStorageLocalizations.of(context)!.invalidUrlFile;
      case ServerFailure():
        return AppwriteStorageLocalizations.of(context)!.serverFailure;
    }
  }
}
