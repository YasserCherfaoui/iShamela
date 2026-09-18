// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'iShamela';

  @override
  String get tabCatalog => 'Catalogue';

  @override
  String get tabLibrary => 'Bibliothèque';

  @override
  String get tabDownloads => 'Téléchargements';

  @override
  String get searchHint => 'Rechercher titres et auteurs';

  @override
  String get categories => 'Catégories';

  @override
  String get authors => 'Auteurs';

  @override
  String get books => 'Livres';

  @override
  String get download => 'Télécharger';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get installed => 'Installé';

  @override
  String get offlineEmpty =>
      'Pas encore de catalogue. Connectez-vous et actualisez.';

  @override
  String get refresh => 'Actualiser le catalogue';

  @override
  String get noBooks => 'Aucun livre';

  @override
  String get downloadError => 'Échec du téléchargement';

  @override
  String get statusQueued => 'En file';

  @override
  String get statusDownloading => 'Téléchargement';

  @override
  String get statusVerifying => 'Vérification';

  @override
  String get statusInstalling => 'Installation';

  @override
  String get statusDone => 'Terminé';

  @override
  String get statusError => 'Erreur';

  @override
  String get statusPaused => 'En pause';

  @override
  String get select => 'Sélectionner';

  @override
  String get downloadSelected => 'Télécharger la sélection';

  @override
  String get downloadAll => 'Tout télécharger';

  @override
  String get confirmDownloadTitle => 'Télécharger les livres ?';

  @override
  String confirmDownloadBody(
    int count,
    String downloadSize,
    String installSize,
  ) {
    return '$count livres · téléchargement $downloadSize · installé ~$installSize';
  }

  @override
  String get confirm => 'Confirmer';

  @override
  String catalogFooter(int bookCount, String installedSize) {
    return '$bookCount livres · installé $installedSize';
  }

  @override
  String get catalogStaleHint =>
      'Le catalogue est peut-être obsolète. Actualisez en ligne.';

  @override
  String pagesCount(int count) {
    return '$count pages';
  }

  @override
  String get openBook => 'Ouvrir';

  @override
  String get jumpToPrintPage => 'Numéro de page imprimée';

  @override
  String get go => 'Aller';

  @override
  String get pageNotFound => 'Page introuvable';

  @override
  String readerProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get searchScopeAll => 'Tout';

  @override
  String get searchScopeBooks => 'Livres';

  @override
  String get searchScopeAuthors => 'Auteurs';

  @override
  String get searchScopeCategories => 'Catégories';

  @override
  String get toc => 'Sommaire';

  @override
  String get bookCard => 'Fiche du livre';

  @override
  String get readingMode => 'Mode de lecture';

  @override
  String get modePagedH => 'Pages · horizontal';

  @override
  String get modePagedV => 'Pages · vertical';

  @override
  String get modeContinuousV => 'Défilement continu';

  @override
  String get searchInBook => 'Chercher dans le livre';

  @override
  String get exactPhrase => 'Expression exacte';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get deselectAll => 'Tout désélectionner';

  @override
  String get highlight => 'Surligner';

  @override
  String get addNote => 'Ajouter une note';

  @override
  String get copyWithReference => 'Copier avec référence';

  @override
  String get copiedCitation => 'Citation copiée';

  @override
  String get colorYellow => 'Jaune';

  @override
  String get colorGreen => 'Vert';

  @override
  String get colorBlue => 'Bleu';

  @override
  String get colorPink => 'Rose';

  @override
  String get colorOrange => 'Orange';
}
