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
  String get previousPage => 'Page précédente';

  @override
  String get nextPage => 'Page suivante';

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

  @override
  String get tabSettings => 'Réglages';

  @override
  String get textAppearance => 'Apparence du texte';

  @override
  String get resetTextStyles => 'Réinitialiser';

  @override
  String get bold => 'Gras';

  @override
  String get pickColor => 'Choisir une couleur';

  @override
  String get colorHex => 'Couleur hex';

  @override
  String get roleBody => 'Corps du texte';

  @override
  String get roleTitle => 'Titres';

  @override
  String get roleHonorific => 'Formules (صلى الله عليه وسلم…)';

  @override
  String get roleQuran => 'Citations coraniques ﴿…﴾';

  @override
  String get rolePunctuation => 'Ponctuation';

  @override
  String get readerFont => 'Police de lecture';

  @override
  String get fontAmiri => 'Amiri';

  @override
  String get fontScheherazade => 'Scheherazade New';

  @override
  String get fontSystem => 'Système';

  @override
  String get fontSize => 'Taille de police';

  @override
  String get notesTab => 'Notes';

  @override
  String get notesEmpty => 'Aucune note';

  @override
  String get tocEmpty => 'Pas de sommaire';

  @override
  String get footnotes => 'Notes de bas de page';

  @override
  String notePageLabel(String page) {
    return 'p. $page';
  }

  @override
  String get downloadsActive => 'Téléchargement';

  @override
  String get downloadsFailed => 'Échec';

  @override
  String get downloadsCompleted => 'Terminé';

  @override
  String get downloadsEmpty => 'Rien ici';

  @override
  String get redownload => 'Retélécharger';

  @override
  String get confirmBulkDelete =>
      'Supprimer les livres sélectionnés de cet appareil ?';

  @override
  String get libraryAllBooks => 'Tous les livres';

  @override
  String get back => 'Retour';

  @override
  String get brandName => 'iSHAMELA';

  @override
  String get unavailableForDownload => 'Non disponible au téléchargement';

  @override
  String sectionWithCount(String label, int count) {
    return '$label · $count';
  }

  @override
  String downloadSelectedCount(int count) {
    return 'Télécharger la sélection ($count)';
  }

  @override
  String get continueReading => 'Continuer la lecture';

  @override
  String get libraryEmptyHint =>
      'Votre bibliothèque est vide — parcourez le catalogue et téléchargez un livre';

  @override
  String get browseCatalog => 'Parcourir le catalogue';

  @override
  String get readingTheme => 'Thème de lecture';

  @override
  String get atmospherePaper => 'Papier';

  @override
  String get atmosphereSepia => 'Sépia';

  @override
  String get atmosphereNight => 'Nuit';

  @override
  String get jumpToPageTitle => 'Aller à la page';

  @override
  String get completedToday => 'Terminé aujourd\'hui';

  @override
  String activeDownloadsCount(int count) {
    return '$count en cours';
  }

  @override
  String get catalogStaleAction => 'Mettre à jour';

  @override
  String catalogStaleDays(int days) {
    return 'Dernière mise à jour il y a $days jours — actualiser';
  }

  @override
  String volumesCount(int count) {
    return '$count vol.';
  }

  @override
  String get copyBibliography => 'Copier la référence';

  @override
  String get historyTitle => 'Historique de lecture';

  @override
  String get historyClear => 'Effacer l\'historique';

  @override
  String get historyClearConfirm =>
      'L\'historique de lecture sera définitivement supprimé.';

  @override
  String get historyEmpty =>
      'Rien lu encore — ouvrez un livre de votre bibliothèque';

  @override
  String get historyLink => 'Historique';

  @override
  String minutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String hoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String daysAgo(int count) {
    return 'il y a $count j';
  }

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get older => 'Plus ancien';

  @override
  String get removeFromHistory => 'Retirer de l\'historique';

  @override
  String get notInstalled => 'Non installé';

  @override
  String get bookmarks => 'Signets';

  @override
  String bookmarkAdded(String page) {
    return 'Signet ajouté · p. $page';
  }

  @override
  String get bookmarkRemoved => 'Signet retiré';

  @override
  String get renameBookmark => 'Renommer le signet';

  @override
  String get bookmarksEmpty =>
      'Pas encore de signets — touchez l\'icône pendant la lecture';

  @override
  String get undo => 'Annuler';

  @override
  String get storage => 'Stockage';

  @override
  String storageUsed(String size, int count) {
    return 'Utilisé : $size ($count livres)';
  }

  @override
  String storageAvailable(String size) {
    return 'Disponible sur l\'appareil : $size';
  }

  @override
  String get manageStorage => 'Gérer le stockage';

  @override
  String get calculatingSizes => 'Calcul des tailles…';

  @override
  String uninstallSelected(int count) {
    return 'Désinstaller la sélection ($count)';
  }

  @override
  String uninstallConfirmSize(String size) {
    return 'Cela libérera $size.';
  }

  @override
  String freeUpSpace(String used, String free) {
    return '$used utilisés · $free disponibles';
  }

  @override
  String get noInstalledBooks => 'Aucun livre installé';

  @override
  String get languageAndApp => 'Langue et application';

  @override
  String get appLanguage => 'Langue de l\'application';

  @override
  String get aboutApp => 'À propos';

  @override
  String version(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get buildCopied => 'Version copiée';

  @override
  String get licenses => 'Licences tierces';

  @override
  String get datasetAttributionTitle => 'Données du corpus';

  @override
  String get datasetAttributionBody =>
      'Données de la bibliothèque Shamela — AuthenticIlm/Shamela4_Full_DB sur Hugging Face. Les textes sont affichés tels quels.';

  @override
  String get sourceCode => 'Code source';

  @override
  String get noConnection => 'Pas de connexion Internet';

  @override
  String get searchScopeTitles => 'Titres';

  @override
  String get searchScopeTexts => 'Texte intégral';

  @override
  String get minQueryHint => 'Saisissez au moins deux caractères';

  @override
  String searchingBooksProgress(int done, int total) {
    return 'Recherche $done sur $total livres…';
  }

  @override
  String hitsCapped(int count) {
    return '$count+';
  }

  @override
  String get moreHitsInBook => 'Voir plus dans le livre';

  @override
  String get libSearchEmpty => 'Aucun résultat dans votre bibliothèque';

  @override
  String get tryCatalogSearch => 'Chercher dans le catalogue';

  @override
  String get searchFailedRetry => 'Échec — toucher pour réessayer';

  @override
  String authorBooksCount(int count) {
    return '$count livres';
  }

  @override
  String authorInstalledCount(int count) {
    return '$count installés';
  }

  @override
  String get showMore => 'Plus';

  @override
  String get showLess => 'Moins';

  @override
  String get allBooks => 'Tous';

  @override
  String get installedOnly => 'Installés';

  @override
  String get noInstalledForAuthor => 'Aucun livre installé de cet auteur';

  @override
  String get filterHint => 'Filtrer…';

  @override
  String diedHijri(int year) {
    return 'm. $year H';
  }

  @override
  String diedCE(int year) {
    return 'm. $year apr. J.-C.';
  }

  @override
  String get exportAnnotations => 'Exporter notes et surlignages';

  @override
  String get exportNoAnnotationsHint => 'Pas d\'annotations dans ce livre';

  @override
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatText => 'Texte';

  @override
  String get includeHighlights => 'Surlignages';

  @override
  String get includeNotes => 'Notes';

  @override
  String get export => 'Exporter';

  @override
  String get exportDone => 'Exporté';

  @override
  String exportedOn(String date) {
    return 'Exporté le $date';
  }

  @override
  String notesFileHeading(String title) {
    return 'Notes — $title';
  }

  @override
  String get noteLabel => 'Note';

  @override
  String downloadingBook(String title) {
    return 'Téléchargement de «$title»';
  }

  @override
  String downloadingNBooks(int count) {
    return 'Téléchargement de $count livres';
  }

  @override
  String get viewDownloads => 'Voir';

  @override
  String downloadCompleteSnack(String title) {
    return 'Téléchargement terminé «$title»';
  }

  @override
  String get open => 'Ouvrir';

  @override
  String downloadFailedSnack(String title) {
    return 'Échec du téléchargement «$title»';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String alreadyInstalled(String title) {
    return '«$title» est déjà installé';
  }

  @override
  String get preparingLibrary => 'Préparation de votre bibliothèque…';

  @override
  String get appTagline =>
      'Votre bibliothèque des sciences islamiques — hors ligne';

  @override
  String get startReading => 'Commencer la lecture';
}
