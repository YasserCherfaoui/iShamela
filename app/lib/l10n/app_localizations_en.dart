// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'iShamela';

  @override
  String get tabCatalog => 'Catalog';

  @override
  String get tabLibrary => 'Library';

  @override
  String get tabDownloads => 'Downloads';

  @override
  String get searchHint => 'Search titles and authors';

  @override
  String get categories => 'Categories';

  @override
  String get authors => 'Authors';

  @override
  String get books => 'Books';

  @override
  String get download => 'Download';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get installed => 'Installed';

  @override
  String get offlineEmpty =>
      'No catalog yet. Connect to the network and refresh.';

  @override
  String get refresh => 'Refresh catalog';

  @override
  String get noBooks => 'No books here';

  @override
  String get downloadError => 'Download failed';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusDownloading => 'Downloading';

  @override
  String get statusVerifying => 'Verifying';

  @override
  String get statusInstalling => 'Installing';

  @override
  String get statusDone => 'Done';

  @override
  String get statusError => 'Error';

  @override
  String get statusPaused => 'Paused';

  @override
  String get select => 'Select';

  @override
  String get downloadSelected => 'Download selected';

  @override
  String get downloadAll => 'Download all';

  @override
  String get confirmDownloadTitle => 'Download books?';

  @override
  String confirmDownloadBody(
    int count,
    String downloadSize,
    String installSize,
  ) {
    return '$count books · download $downloadSize · installed ~$installSize';
  }

  @override
  String get confirm => 'Confirm';

  @override
  String catalogFooter(int bookCount, String installedSize) {
    return '$bookCount books · installed $installedSize';
  }

  @override
  String get catalogStaleHint =>
      'Catalog may be out of date. Pull to refresh when online.';

  @override
  String pagesCount(int count) {
    return '$count pages';
  }

  @override
  String get openBook => 'Open';

  @override
  String get jumpToPrintPage => 'Print page number';

  @override
  String get go => 'Go';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String readerProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get searchScopeAll => 'All';

  @override
  String get searchScopeBooks => 'Books';

  @override
  String get searchScopeAuthors => 'Authors';

  @override
  String get searchScopeCategories => 'Categories';

  @override
  String get toc => 'Contents';

  @override
  String get bookCard => 'Book card';

  @override
  String get readingMode => 'Reading mode';

  @override
  String get modePagedH => 'Pages · horizontal';

  @override
  String get modePagedV => 'Pages · vertical';

  @override
  String get modeContinuousV => 'Continuous scroll';

  @override
  String get searchInBook => 'Search in book';

  @override
  String get exactPhrase => 'Exact phrase';

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get highlight => 'Highlight';

  @override
  String get removeHighlight => 'Remove highlight';

  @override
  String get addNote => 'Add note';

  @override
  String get copyWithReference => 'Copy with reference';

  @override
  String get copiedCitation => 'Citation copied';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorOrange => 'Orange';

  @override
  String get tabSettings => 'Settings';

  @override
  String get textAppearance => 'Text appearance';

  @override
  String get resetTextStyles => 'Reset';

  @override
  String get bold => 'Bold';

  @override
  String get pickColor => 'Pick color';

  @override
  String get colorHex => 'Hex color';

  @override
  String get roleBody => 'Body text';

  @override
  String get roleTitle => 'Titles';

  @override
  String get roleHonorific => 'Honorifics (صلى الله عليه وسلم…)';

  @override
  String get roleQuran => 'Quran quotes ﴿…﴾';

  @override
  String get rolePunctuation => 'Punctuation';

  @override
  String get readerFont => 'Reader font';

  @override
  String get fontAmiri => 'Amiri';

  @override
  String get fontScheherazade => 'Scheherazade New';

  @override
  String get fontSystem => 'System';

  @override
  String get fontSize => 'Font size';

  @override
  String get notesTab => 'Notes';

  @override
  String get notesEmpty => 'No notes yet';

  @override
  String get tocEmpty => 'No table of contents';

  @override
  String get footnotes => 'Footnotes';

  @override
  String notePageLabel(String page) {
    return 'p. $page';
  }

  @override
  String get downloadsActive => 'Downloading';

  @override
  String get downloadsFailed => 'Failed';

  @override
  String get downloadsCompleted => 'Completed';

  @override
  String get downloadsEmpty => 'Nothing here';

  @override
  String get redownload => 'Redownload';

  @override
  String get confirmBulkDelete => 'Delete the selected books from this device?';

  @override
  String get libraryAllBooks => 'All books';

  @override
  String get back => 'Back';

  @override
  String get brandName => 'iSHAMELA';

  @override
  String get unavailableForDownload => 'Not available for download';

  @override
  String sectionWithCount(String label, int count) {
    return '$label · $count';
  }

  @override
  String downloadSelectedCount(int count) {
    return 'Download selected ($count)';
  }

  @override
  String get continueReading => 'Continue reading';

  @override
  String get libraryEmptyHint =>
      'Your library is empty — browse the catalog and download a book';

  @override
  String get browseCatalog => 'Browse catalog';

  @override
  String get readingTheme => 'Reading theme';

  @override
  String get atmospherePaper => 'Paper';

  @override
  String get atmosphereSepia => 'Sepia';

  @override
  String get atmosphereNight => 'Night';

  @override
  String get jumpToPageTitle => 'Go to page';

  @override
  String get completedToday => 'Completed today';

  @override
  String activeDownloadsCount(int count) {
    return '$count active';
  }

  @override
  String get catalogStaleAction => 'Update now';

  @override
  String catalogStaleDays(int days) {
    return 'Last updated $days days ago — update now';
  }

  @override
  String volumesCount(int count) {
    return '$count vols';
  }

  @override
  String get copyBibliography => 'Copy citation';

  @override
  String get historyTitle => 'Reading history';

  @override
  String get historyClear => 'Clear history';

  @override
  String get historyClearConfirm =>
      'Reading history will be permanently deleted.';

  @override
  String get historyEmpty => 'Nothing read yet — open a book from your library';

  @override
  String get historyLink => 'History';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This week';

  @override
  String get older => 'Older';

  @override
  String get removeFromHistory => 'Remove from history';

  @override
  String get notInstalled => 'Not installed';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String bookmarkAdded(String page) {
    return 'Bookmark added · p. $page';
  }

  @override
  String get bookmarkRemoved => 'Bookmark removed';

  @override
  String get renameBookmark => 'Rename bookmark';

  @override
  String get bookmarksEmpty =>
      'No bookmarks yet — tap the bookmark icon while reading';

  @override
  String get undo => 'Undo';

  @override
  String get storage => 'Storage';

  @override
  String storageUsed(String size, int count) {
    return 'Used: $size ($count books)';
  }

  @override
  String storageAvailable(String size) {
    return 'Available on device: $size';
  }

  @override
  String get manageStorage => 'Manage storage';

  @override
  String get calculatingSizes => 'Calculating sizes…';

  @override
  String uninstallSelected(int count) {
    return 'Uninstall selected ($count)';
  }

  @override
  String uninstallConfirmSize(String size) {
    return 'This will free $size.';
  }

  @override
  String freeUpSpace(String used, String free) {
    return '$used used · $free available';
  }

  @override
  String get noInstalledBooks => 'No installed books';

  @override
  String get languageAndApp => 'Language & app';

  @override
  String get appLanguage => 'App language';

  @override
  String get aboutApp => 'About';

  @override
  String version(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get buildCopied => 'Version copied';

  @override
  String get licenses => 'Third-party licenses';

  @override
  String get datasetAttributionTitle => 'Corpus data';

  @override
  String get datasetAttributionBody =>
      'Shamela library data — AuthenticIlm/Shamela4_Full_DB on Hugging Face. Texts are shown verbatim from the corpus.';

  @override
  String get sourceCode => 'Source code';

  @override
  String get noConnection => 'No internet connection';

  @override
  String get searchScopeTitles => 'Titles';

  @override
  String get searchScopeTexts => 'Full text';

  @override
  String get minQueryHint => 'Enter at least two characters';

  @override
  String searchingBooksProgress(int done, int total) {
    return 'Searching $done of $total books…';
  }

  @override
  String hitsCapped(int count) {
    return '$count+';
  }

  @override
  String get moreHitsInBook => 'Show more in book';

  @override
  String get libSearchEmpty => 'No results in your library';

  @override
  String get tryCatalogSearch => 'Search the catalog';

  @override
  String get searchFailedRetry => 'Search failed — tap to retry';

  @override
  String authorBooksCount(int count) {
    return '$count books';
  }

  @override
  String authorInstalledCount(int count) {
    return '$count installed';
  }

  @override
  String get showMore => 'More';

  @override
  String get showLess => 'Less';

  @override
  String get allBooks => 'All';

  @override
  String get installedOnly => 'Installed';

  @override
  String get noInstalledForAuthor => 'No installed books by this author';

  @override
  String get filterHint => 'Filter…';

  @override
  String diedHijri(int year) {
    return 'd. $year AH';
  }

  @override
  String diedCE(int year) {
    return 'd. $year CE';
  }

  @override
  String get exportAnnotations => 'Export notes & highlights';

  @override
  String get exportNoAnnotationsHint => 'No annotations in this book';

  @override
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatText => 'Plain text';

  @override
  String get includeHighlights => 'Highlights';

  @override
  String get includeNotes => 'Notes';

  @override
  String get export => 'Export';

  @override
  String get exportDone => 'Exported';

  @override
  String exportedOn(String date) {
    return 'Exported on $date';
  }

  @override
  String notesFileHeading(String title) {
    return 'Notes — $title';
  }

  @override
  String get noteLabel => 'Note';

  @override
  String downloadingBook(String title) {
    return 'Downloading «$title»';
  }

  @override
  String downloadingNBooks(int count) {
    return 'Downloading $count books';
  }

  @override
  String get viewDownloads => 'View';

  @override
  String downloadCompleteSnack(String title) {
    return 'Finished downloading «$title»';
  }

  @override
  String get open => 'Open';

  @override
  String downloadFailedSnack(String title) {
    return 'Could not download «$title»';
  }

  @override
  String get retry => 'Retry';

  @override
  String alreadyInstalled(String title) {
    return '«$title» is already installed';
  }

  @override
  String get preparingLibrary => 'Preparing your library…';

  @override
  String get appTagline => 'Your library of Islamic sciences — offline';

  @override
  String get startReading => 'Start reading';

  @override
  String get tabHome => 'Home';

  @override
  String get homeGreeting => 'Peace be upon you';

  @override
  String homeGreetingNamed(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeHijriApprox => 'approx.';

  @override
  String get homeContinueReading => 'Continue reading';

  @override
  String homeContinueA11y(String title, String part, String page) {
    return 'Continue reading $title, volume $part, page $page';
  }

  @override
  String homeBookCrumb(String book, String section) {
    return 'Book $book · Chapter $section';
  }

  @override
  String homeVolPage(String vol, String page) {
    return 'Vol. $vol · p. $page';
  }

  @override
  String homePageOnly(String page) {
    return 'p. $page';
  }

  @override
  String homePercent(String pct) {
    return '$pct%';
  }

  @override
  String get homeStreakDays => 'Day streak';

  @override
  String get homeWeeklyMinutes => 'Minutes this week';

  @override
  String get homeWeeklyPages => 'Pages this week';

  @override
  String get homeRecentHistory => 'Recent reading';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeQuickBookmarks => 'Bookmarks';

  @override
  String get homeQuickNotes => 'My notes';

  @override
  String get homeSyncBanner => 'Sign in to sync your reading across devices';

  @override
  String get homeSyncBannerCta => 'Sign in';

  @override
  String get homeEmptyTitle => 'Start your journey with the library';

  @override
  String get homeEmptyCta => 'Browse the catalog';

  @override
  String get homeBookNotDownloaded => 'Book not downloaded';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileGuest => 'Guest';

  @override
  String get profileGuestCopy =>
      'You\'re using the app without an account — your data stays on this device only';

  @override
  String get profileSignInCta => 'Sign in or create an account';

  @override
  String get profileEditName => 'Edit name';

  @override
  String get profileEditNameHint => 'Name (1–40 characters)';

  @override
  String get profileEditNameSave => 'Save';

  @override
  String get profileEditNameSaved => 'Name updated';

  @override
  String get profileEditNameInvalid => 'Name must be 1–40 characters';

  @override
  String get profileLifetimeBooks => 'Books started';

  @override
  String get profileLifetimePages => 'Pages read';

  @override
  String get profileLifetimeMinutes => 'Reading minutes';

  @override
  String get profileLongestStreak => 'Longest streak';

  @override
  String get profileSync => 'Sync';

  @override
  String profileLastSynced(String relative) {
    return 'Last synced: $relative';
  }

  @override
  String get profileNeverSynced => 'Not synced yet';

  @override
  String get profileSyncNow => 'Sync now';

  @override
  String get profileSyncing => 'Syncing your data…';

  @override
  String get profileSyncCellular => 'Sync over mobile data';

  @override
  String get profileAutoDownload => 'Automatically download my library';

  @override
  String get librarySyncSection => 'Library sync';

  @override
  String get libraryWaitingWifi => 'Waiting for Wi-Fi';

  @override
  String get librarySetupTitle => 'Download your library';

  @override
  String librarySetupBody(String count, String size) {
    return '$count books · $size';
  }

  @override
  String get libraryDownloadAll => 'Download all';

  @override
  String get libraryChoose => 'Choose';

  @override
  String get libraryLater => 'Later';

  @override
  String libraryStorageShort(String size) {
    return 'Not enough space to download your library ($size required)';
  }

  @override
  String get libraryChooseBooks => 'Choose books';

  @override
  String get libraryManageStorage => 'Manage storage';

  @override
  String get libraryRemoveDevice => 'Remove from this device';

  @override
  String get libraryRemoveAll => 'Remove from all devices';

  @override
  String get libraryUnavailable => 'Currently unavailable';

  @override
  String get profileSyncError => 'Sync failed — try again';

  @override
  String get profileShortcutStorage => 'Manage storage';

  @override
  String get profileShortcutHistory => 'Reading history';

  @override
  String get profileShortcutBookmarks => 'Bookmarks';

  @override
  String get profileShortcutNotes => 'My notes';

  @override
  String get profileShortcutSettings => 'Settings';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileCurrentPassword => 'Current password';

  @override
  String get profileNewPassword => 'New password';

  @override
  String get profileConfirmPassword => 'Confirm password';

  @override
  String get profilePasswordChanged => 'Password changed';

  @override
  String get profilePasswordMismatch => 'Passwords do not match';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileSignOutConfirm =>
      'Your history and notes will stay on this device';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileDeleteExplain =>
      'Your cloud account and all synced data will be deleted. Local data on this device is kept unless you check the option below.';

  @override
  String get profileDeleteWipeLocal => 'Also delete my data from this device';

  @override
  String get profileDeleteTypeConfirm => 'Type «حذف» to confirm';

  @override
  String get profileDeleteConfirmWord => 'حذف';

  @override
  String get profileDeleteDone => 'Account deleted';

  @override
  String get profileDeleteFailed => 'Could not delete account — try again';

  @override
  String get profileAccount => 'Account';

  @override
  String get bookmarksListTitle => 'Bookmarks';

  @override
  String get notesListTitle => 'My notes';

  @override
  String get notesListEmpty => 'No notes yet — add one while reading';

  @override
  String get authValueCopy =>
      'Sign in to sync your reading and notes across devices';

  @override
  String get authContinueApple => 'Continue with Apple';

  @override
  String get authContinueGoogle => 'Continue with Google';

  @override
  String get authContinueEmail => 'Email';

  @override
  String get authContinueGuest => 'Continue without an account';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignUpTitle => 'Create account';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authCreateAccount => 'Create an account';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authForgotTitle => 'Reset password';

  @override
  String get authForgotCopy => 'We will send a 6-digit code to your email';

  @override
  String get authForgotSuccess =>
      'If that email is registered, you will receive a code';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authDisplayName => 'Name';

  @override
  String get authFieldRequired => 'Required';

  @override
  String get authInvalidEmail => 'Invalid email';

  @override
  String get authPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authPasswordStrengthWeak => 'Weak';

  @override
  String get authPasswordStrengthOk => 'OK';

  @override
  String get authPasswordStrengthStrong => 'Strong';

  @override
  String get authPasswordChanged => 'Password changed';

  @override
  String get authMustAcceptTerms =>
      'Please accept the privacy policy and terms';

  @override
  String get authAcceptPrefix => 'I agree to the';

  @override
  String get authAcceptAnd => 'and';

  @override
  String get authPrivacy => 'Privacy Policy';

  @override
  String get authTerms => 'Terms';

  @override
  String get authOtpTitle => 'Enter the code';

  @override
  String authOtpCopy(String email) {
    return 'A 6-digit code was sent to $email';
  }

  @override
  String get authVerifyCode => 'Verify';

  @override
  String authOtpResendIn(String time) {
    return 'Resend in $time';
  }

  @override
  String get authOtpResend => 'Resend code';

  @override
  String get authOtpResent => 'Code sent';

  @override
  String get authOtpWrong => 'Incorrect code';

  @override
  String get authOtpExpired => 'Code expired — request a new one';

  @override
  String get authOtpLocked => 'Too many attempts — request a new code';

  @override
  String get authResetTitle => 'New password';

  @override
  String get authSavePassword => 'Save password';

  @override
  String get authWelcomeVerified => 'Welcome — your account is verified';

  @override
  String get authWrongCredentials => 'Incorrect email or password';

  @override
  String get authEmailAlreadyInUse => 'Email already in use';

  @override
  String get authWeakPassword => 'Password is too weak';

  @override
  String get authTooManyRequests => 'Too many attempts — try again later';

  @override
  String get authNetworkError => 'Network error — try again';

  @override
  String get authRequiresRecentLogin => 'Please sign in again to continue';

  @override
  String get authSessionExpired => 'Session ended — sign in again to sync';

  @override
  String get authUnavailable => 'Sign-in is unavailable right now';

  @override
  String get authGenericError => 'Something went wrong';

  @override
  String get authSyncInProgress => 'Syncing your data…';

  @override
  String get authSyncFailed => 'Sync failed — will retry later';
}
