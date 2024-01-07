import 'appwrite_storage_localizations.dart';

/// The translations for English (`en`).
class AppwriteStorageLocalizationsEn extends AppwriteStorageLocalizations {
  AppwriteStorageLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get noPermissionFailure => 'You do not have permissions to access this resource. If the problem persists, please contact your system administrator';

  @override
  String get uploadFileFailure => 'Failed to upload file. Plese try again later';

  @override
  String get removeFileFailure => 'Failed to remove file. Plese try again later';

  @override
  String get updateFileFailure => 'Failed to update file. Plese try again later';

  @override
  String get invalidUrlFile => 'Invalid URL';

  @override
  String get serverFailure => 'A server error has occurred. If the problem persists, please contact your system administrator';
}
