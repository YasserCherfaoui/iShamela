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
}
