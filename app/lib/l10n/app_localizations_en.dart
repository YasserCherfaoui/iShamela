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
}
