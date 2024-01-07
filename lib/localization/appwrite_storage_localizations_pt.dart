import 'appwrite_storage_localizations.dart';

/// The translations for Portuguese (`pt`).
class AppwriteStorageLocalizationsPt extends AppwriteStorageLocalizations {
  AppwriteStorageLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get noPermissionFailure => 'Não há permissão para realizar esta ação';

  @override
  String get uploadFileFailure => 'Erro ao carregar o arquivo. Por favor, tente novamente mais tarde';

  @override
  String get removeFileFailure => 'Erro ao excluir o arquivo. Por favor, tente novamente mais tarde';

  @override
  String get updateFileFailure => 'Erro ao atualizar o arquivo. Por favor, tente novamente mais tarde';

  @override
  String get invalidUrlFile => 'A URL do arquivo não é válida';

  @override
  String get serverFailure => 'Erro no servidor. Por favor, tente novamente mais tarde';
}
