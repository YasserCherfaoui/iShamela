import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'الشاملة'**
  String get appTitle;

  /// No description provided for @tabCatalog.
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get tabCatalog;

  /// No description provided for @tabLibrary.
  ///
  /// In ar, this message translates to:
  /// **'مكتبتي'**
  String get tabLibrary;

  /// No description provided for @tabDownloads.
  ///
  /// In ar, this message translates to:
  /// **'التنزيلات'**
  String get tabDownloads;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في العناوين والمؤلفين'**
  String get searchHint;

  /// No description provided for @categories.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام'**
  String get categories;

  /// No description provided for @authors.
  ///
  /// In ar, this message translates to:
  /// **'المؤلفون'**
  String get authors;

  /// No description provided for @books.
  ///
  /// In ar, this message translates to:
  /// **'الكتب'**
  String get books;

  /// No description provided for @download.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل'**
  String get download;

  /// No description provided for @pause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get resume;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @installed.
  ///
  /// In ar, this message translates to:
  /// **'مثبّت'**
  String get installed;

  /// No description provided for @offlineEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يتوفر فهرس بعد. اتصل بالشبكة ثم حدّث.'**
  String get offlineEmpty;

  /// No description provided for @refresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الفهرس'**
  String get refresh;

  /// No description provided for @noBooks.
  ///
  /// In ar, this message translates to:
  /// **'لا كتب هنا'**
  String get noBooks;

  /// No description provided for @downloadError.
  ///
  /// In ar, this message translates to:
  /// **'فشل التنزيل'**
  String get downloadError;

  /// No description provided for @statusQueued.
  ///
  /// In ar, this message translates to:
  /// **'في الانتظار'**
  String get statusQueued;

  /// No description provided for @statusDownloading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التنزيل'**
  String get statusDownloading;

  /// No description provided for @statusVerifying.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق'**
  String get statusVerifying;

  /// No description provided for @statusInstalling.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التثبيت'**
  String get statusInstalling;

  /// No description provided for @statusDone.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get statusDone;

  /// No description provided for @statusError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get statusError;

  /// No description provided for @statusPaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get statusPaused;

  /// No description provided for @select.
  ///
  /// In ar, this message translates to:
  /// **'تحديد'**
  String get select;

  /// No description provided for @downloadSelected.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل المحدد'**
  String get downloadSelected;

  /// No description provided for @downloadAll.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل الكل'**
  String get downloadAll;

  /// No description provided for @confirmDownloadTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل الكتب؟'**
  String get confirmDownloadTitle;

  /// No description provided for @confirmDownloadBody.
  ///
  /// In ar, this message translates to:
  /// **'{count} كتاب · تنزيل {downloadSize} · تثبيت ≈ {installSize}'**
  String confirmDownloadBody(
    int count,
    String downloadSize,
    String installSize,
  );

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @catalogFooter.
  ///
  /// In ar, this message translates to:
  /// **'{bookCount} كتاب · المثبّت {installedSize}'**
  String catalogFooter(int bookCount, String installedSize);

  /// No description provided for @catalogStaleHint.
  ///
  /// In ar, this message translates to:
  /// **'قد يكون الفهرس قديماً. حدّث عند الاتصال بالشبكة.'**
  String get catalogStaleHint;

  /// No description provided for @pagesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} صفحة'**
  String pagesCount(int count);

  /// No description provided for @openBook.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get openBook;

  /// No description provided for @jumpToPrintPage.
  ///
  /// In ar, this message translates to:
  /// **'رقم الصفحة المطبوعة'**
  String get jumpToPrintPage;

  /// No description provided for @go.
  ///
  /// In ar, this message translates to:
  /// **'انتقال'**
  String get go;

  /// No description provided for @pageNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الصفحة غير موجودة'**
  String get pageNotFound;

  /// No description provided for @readerProgress.
  ///
  /// In ar, this message translates to:
  /// **'{current} / {total}'**
  String readerProgress(int current, int total);

  /// No description provided for @searchScopeAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get searchScopeAll;

  /// No description provided for @searchScopeBooks.
  ///
  /// In ar, this message translates to:
  /// **'كتب'**
  String get searchScopeBooks;

  /// No description provided for @searchScopeAuthors.
  ///
  /// In ar, this message translates to:
  /// **'مؤلفون'**
  String get searchScopeAuthors;

  /// No description provided for @searchScopeCategories.
  ///
  /// In ar, this message translates to:
  /// **'أقسام'**
  String get searchScopeCategories;

  /// No description provided for @toc.
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get toc;

  /// No description provided for @bookCard.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة الكتاب'**
  String get bookCard;

  /// No description provided for @readingMode.
  ///
  /// In ar, this message translates to:
  /// **'وضع القراءة'**
  String get readingMode;

  /// No description provided for @modePagedH.
  ///
  /// In ar, this message translates to:
  /// **'صفحات · أفقي'**
  String get modePagedH;

  /// No description provided for @modePagedV.
  ///
  /// In ar, this message translates to:
  /// **'صفحات · عمودي'**
  String get modePagedV;

  /// No description provided for @modeContinuousV.
  ///
  /// In ar, this message translates to:
  /// **'تمرير متصل'**
  String get modeContinuousV;

  /// No description provided for @searchInBook.
  ///
  /// In ar, this message translates to:
  /// **'بحث في الكتاب'**
  String get searchInBook;

  /// No description provided for @exactPhrase.
  ///
  /// In ar, this message translates to:
  /// **'عبارة كاملة'**
  String get exactPhrase;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
