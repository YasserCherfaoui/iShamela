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
  String get removeHighlight => 'Retirer le surlignage';

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

  @override
  String get tabHome => 'Accueil';

  @override
  String get homeGreeting => 'Que la paix soit sur vous';

  @override
  String homeGreetingNamed(String name) {
    return 'Bonjour, $name';
  }

  @override
  String get homeHijriApprox => 'approx.';

  @override
  String get homeContinueReading => 'Continuer la lecture';

  @override
  String homeContinueA11y(String title, String part, String page) {
    return 'Continuer la lecture de $title, volume $part, page $page';
  }

  @override
  String homeBookCrumb(String book, String section) {
    return 'Livre $book · Chapitre $section';
  }

  @override
  String homeVolPage(String vol, String page) {
    return 'T. $vol · p. $page';
  }

  @override
  String homePageOnly(String page) {
    return 'p. $page';
  }

  @override
  String homePercent(String pct) {
    return '$pct %';
  }

  @override
  String get homeStreakDays => 'Jours consécutifs';

  @override
  String get homeWeeklyMinutes => 'Minutes cette semaine';

  @override
  String get homeWeeklyPages => 'Pages cette semaine';

  @override
  String get homeRecentHistory => 'Lectures récentes';

  @override
  String get homeViewAll => 'Tout voir';

  @override
  String get homeQuickBookmarks => 'Signets';

  @override
  String get homeQuickNotes => 'Mes notes';

  @override
  String get homeSyncBanner => 'Connectez-vous pour synchroniser vos lectures';

  @override
  String get homeSyncBannerCta => 'Se connecter';

  @override
  String get homeEmptyTitle => 'Commencez votre parcours avec la bibliothèque';

  @override
  String get homeEmptyCta => 'Parcourir le catalogue';

  @override
  String get homeBookNotDownloaded => 'Livre non téléchargé';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileGuest => 'Invité';

  @override
  String get profileGuestCopy =>
      'Vous utilisez l\'application sans compte — vos données restent sur cet appareil uniquement';

  @override
  String get profileSignInCta => 'Se connecter ou créer un compte';

  @override
  String get profileEditName => 'Modifier le nom';

  @override
  String get profileEditNameHint => 'Nom (1–40 caractères)';

  @override
  String get profileEditNameSave => 'Enregistrer';

  @override
  String get profileEditNameSaved => 'Nom mis à jour';

  @override
  String get profileEditNameInvalid => 'Le nom doit contenir 1 à 40 caractères';

  @override
  String get profileLifetimeBooks => 'Livres commencés';

  @override
  String get profileLifetimePages => 'Pages lues';

  @override
  String get profileLifetimeMinutes => 'Minutes de lecture';

  @override
  String get profileLongestStreak => 'Plus longue série';

  @override
  String get profileSync => 'Synchronisation';

  @override
  String profileLastSynced(String relative) {
    return 'Dernière sync : $relative';
  }

  @override
  String get profileNeverSynced => 'Pas encore synchronisé';

  @override
  String get profileSyncNow => 'Synchroniser';

  @override
  String get profileSyncing => 'Synchronisation en cours…';

  @override
  String get profileSyncCellular => 'Sync via données mobiles';

  @override
  String get profileAutoDownload =>
      'Télécharger ma bibliothèque automatiquement';

  @override
  String get librarySyncSection => 'Sync de la bibliothèque';

  @override
  String get libraryWaitingWifi => 'En attente du Wi-Fi';

  @override
  String get librarySetupTitle => 'Télécharger votre bibliothèque';

  @override
  String librarySetupBody(String count, String size) {
    return '$count livres · $size';
  }

  @override
  String get libraryDownloadAll => 'Tout télécharger';

  @override
  String get libraryChoose => 'Choisir';

  @override
  String get libraryLater => 'Plus tard';

  @override
  String libraryStorageShort(String size) {
    return 'Espace insuffisant pour télécharger votre bibliothèque ($size requis)';
  }

  @override
  String get libraryChooseBooks => 'Choisir les livres';

  @override
  String get libraryManageStorage => 'Gérer le stockage';

  @override
  String get libraryRemoveDevice => 'Retirer de cet appareil';

  @override
  String get libraryRemoveAll => 'Retirer de tous les appareils';

  @override
  String get libraryUnavailable => 'Indisponible pour le moment';

  @override
  String get profileSyncError => 'Échec de la sync — réessayez';

  @override
  String get profileShortcutStorage => 'Gérer le stockage';

  @override
  String get profileShortcutHistory => 'Historique de lecture';

  @override
  String get profileShortcutBookmarks => 'Signets';

  @override
  String get profileShortcutNotes => 'Mes notes';

  @override
  String get profileShortcutSettings => 'Paramètres';

  @override
  String get profileChangePassword => 'Changer le mot de passe';

  @override
  String get profileCurrentPassword => 'Mot de passe actuel';

  @override
  String get profileNewPassword => 'Nouveau mot de passe';

  @override
  String get profileConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get profilePasswordChanged => 'Mot de passe modifié';

  @override
  String get profilePasswordMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get profileSignOut => 'Se déconnecter';

  @override
  String get profileSignOutConfirm =>
      'Votre historique et vos notes resteront sur cet appareil';

  @override
  String get profileDeleteAccount => 'Supprimer le compte';

  @override
  String get profileDeleteExplain =>
      'Votre compte cloud et toutes les données synchronisées seront supprimés. Les données locales restent sauf si vous cochez l\'option ci-dessous.';

  @override
  String get profileDeleteWipeLocal =>
      'Supprimer aussi mes données de cet appareil';

  @override
  String get profileDeleteTypeConfirm => 'Tapez «حذف» pour confirmer';

  @override
  String get profileDeleteConfirmWord => 'حذف';

  @override
  String get profileDeleteDone => 'Compte supprimé';

  @override
  String get profileDeleteFailed =>
      'Impossible de supprimer le compte — réessayez';

  @override
  String get profileAccount => 'Compte';

  @override
  String get bookmarksListTitle => 'Signets';

  @override
  String get notesListTitle => 'Mes notes';

  @override
  String get notesListEmpty => 'Aucune note — ajoutez-en en lisant';

  @override
  String get authValueCopy =>
      'Connectez-vous pour synchroniser lectures et notes sur vos appareils';

  @override
  String get authContinueApple => 'Continuer avec Apple';

  @override
  String get authContinueGoogle => 'Continuer avec Google';

  @override
  String get authContinueEmail => 'E-mail';

  @override
  String get authContinueGuest => 'Continuer sans compte';

  @override
  String get authSignInTitle => 'Connexion';

  @override
  String get authSignUpTitle => 'Créer un compte';

  @override
  String get authSignIn => 'Se connecter';

  @override
  String get authSignUp => 'Créer un compte';

  @override
  String get authCreateAccount => 'Créer un compte';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authForgotTitle => 'Mot de passe oublié';

  @override
  String get authForgotCopy =>
      'Nous enverrons un code à 6 chiffres à votre e-mail';

  @override
  String get authForgotSuccess =>
      'Si cet e-mail est enregistré, vous recevrez un code';

  @override
  String get authSendCode => 'Envoyer le code';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authNewPassword => 'Nouveau mot de passe';

  @override
  String get authConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get authDisplayName => 'Nom';

  @override
  String get authFieldRequired => 'Ce champ est requis';

  @override
  String get authInvalidEmail => 'E-mail invalide';

  @override
  String get authPasswordTooShort =>
      'Le mot de passe doit contenir au moins 8 caractères';

  @override
  String get authPasswordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get authPasswordStrengthWeak => 'Faible — ajoutez lettres et chiffres';

  @override
  String get authPasswordStrengthOk => 'Correct';

  @override
  String get authPasswordStrengthStrong => 'Fort';

  @override
  String get authPasswordChanged => 'Mot de passe modifié';

  @override
  String get authMustAcceptTerms =>
      'Veuillez accepter la politique et les conditions';

  @override
  String get authAcceptPrefix => 'J\'accepte la';

  @override
  String get authAcceptAnd => 'et les';

  @override
  String get authPrivacy => 'Politique de confidentialité';

  @override
  String get authTerms => 'Conditions';

  @override
  String get authOtpTitle => 'Code de vérification';

  @override
  String authOtpCopy(String email) {
    return 'Saisissez le code à 6 chiffres envoyé à $email';
  }

  @override
  String get authVerifyCode => 'Vérifier';

  @override
  String authOtpResendIn(String time) {
    return 'Renvoyer dans $time';
  }

  @override
  String get authOtpResend => 'Renvoyer le code';

  @override
  String get authOtpResent => 'Code renvoyé';

  @override
  String get authOtpWrong => 'Code incorrect';

  @override
  String get authOtpExpired => 'Code expiré — demandez-en un nouveau';

  @override
  String get authOtpLocked => 'Trop de tentatives — demandez un nouveau code';

  @override
  String get authResetTitle => 'Nouveau mot de passe';

  @override
  String get authSavePassword => 'Enregistrer le mot de passe';

  @override
  String get authWelcomeVerified => 'Bienvenue — e-mail vérifié';

  @override
  String get authWrongCredentials => 'E-mail ou mot de passe incorrect';

  @override
  String get authEmailAlreadyInUse => 'Cet e-mail est déjà utilisé';

  @override
  String get authWeakPassword => 'Mot de passe trop faible';

  @override
  String get authTooManyRequests => 'Trop de tentatives — réessayez plus tard';

  @override
  String get authNetworkError => 'Erreur réseau — vérifiez la connexion';

  @override
  String get authRequiresRecentLogin => 'Reconnectez-vous pour continuer';

  @override
  String get authSessionExpired =>
      'Session terminée — reconnectez-vous pour synchroniser';

  @override
  String get authUnavailable => 'La connexion est indisponible pour le moment';

  @override
  String get authGenericError => 'Une erreur s\'est produite — réessayez';

  @override
  String get authSyncInProgress => 'Synchronisation de vos données…';

  @override
  String get authSyncFailed =>
      'Échec de la synchronisation — nouvel essai plus tard';
}
