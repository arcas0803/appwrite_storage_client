import 'appwrite_storage_localizations.dart';

/// The translations for Spanish Castilian (`es`).
class AppwriteStorageLocalizationsEs extends AppwriteStorageLocalizations {
  AppwriteStorageLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get noPermissionFailure => 'No tienes permiso para realizar esta acción';

  @override
  String get uploadFileFailure => 'Error al subir el archivo. Por favor, inténtelo de nuevo más tarde';

  @override
  String get removeFileFailure => 'Error al eliminar el archivo. Por favor, inténtelo de nuevo más tarde';

  @override
  String get updateFileFailure => 'Error al actualizar el archivo. Por favor, inténtelo de nuevo más tarde';

  @override
  String get invalidUrlFile => 'La URL del archivo no es válida';

  @override
  String get serverFailure => 'Error del servidor. Por favor, inténtelo de nuevo más tarde';
}
