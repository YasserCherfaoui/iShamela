// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'الشاملة';

  @override
  String get tabCatalog => 'الفهرس';

  @override
  String get tabLibrary => 'مكتبتي';

  @override
  String get tabDownloads => 'التنزيلات';

  @override
  String get searchHint => 'ابحث في العناوين والمؤلفين';

  @override
  String get categories => 'الأقسام';

  @override
  String get authors => 'المؤلفون';

  @override
  String get books => 'الكتب';

  @override
  String get download => 'تنزيل';

  @override
  String get pause => 'إيقاف';

  @override
  String get resume => 'استئناف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get installed => 'مثبّت';

  @override
  String get offlineEmpty => 'لا يتوفر فهرس بعد. اتصل بالشبكة ثم حدّث.';

  @override
  String get refresh => 'تحديث الفهرس';

  @override
  String get noBooks => 'لا كتب هنا';

  @override
  String get downloadError => 'فشل التنزيل';

  @override
  String get statusQueued => 'في الانتظار';

  @override
  String get statusDownloading => 'جارٍ التنزيل';

  @override
  String get statusVerifying => 'جارٍ التحقق';

  @override
  String get statusInstalling => 'جارٍ التثبيت';

  @override
  String get statusDone => 'مكتمل';

  @override
  String get statusError => 'خطأ';

  @override
  String get statusPaused => 'متوقف';

  @override
  String get select => 'تحديد';

  @override
  String get downloadSelected => 'تنزيل المحدد';

  @override
  String get downloadAll => 'تنزيل الكل';

  @override
  String get confirmDownloadTitle => 'تنزيل الكتب؟';

  @override
  String confirmDownloadBody(
    int count,
    String downloadSize,
    String installSize,
  ) {
    return '$count كتاب · تنزيل $downloadSize · تثبيت ≈ $installSize';
  }

  @override
  String get confirm => 'تأكيد';

  @override
  String catalogFooter(int bookCount, String installedSize) {
    return '$bookCount كتاب · المثبّت $installedSize';
  }

  @override
  String get catalogStaleHint =>
      'قد يكون الفهرس قديماً. حدّث عند الاتصال بالشبكة.';

  @override
  String pagesCount(int count) {
    return '$count صفحة';
  }

  @override
  String get openBook => 'فتح';

  @override
  String get jumpToPrintPage => 'رقم الصفحة المطبوعة';

  @override
  String get go => 'انتقال';

  @override
  String get previousPage => 'الصفحة السابقة';

  @override
  String get nextPage => 'الصفحة التالية';

  @override
  String get pageNotFound => 'الصفحة غير موجودة';

  @override
  String readerProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get searchScopeAll => 'الكل';

  @override
  String get searchScopeBooks => 'كتب';

  @override
  String get searchScopeAuthors => 'مؤلفون';

  @override
  String get searchScopeCategories => 'أقسام';

  @override
  String get toc => 'الفهرس';

  @override
  String get bookCard => 'بطاقة الكتاب';

  @override
  String get readingMode => 'وضع القراءة';

  @override
  String get modePagedH => 'صفحات · أفقي';

  @override
  String get modePagedV => 'صفحات · عمودي';

  @override
  String get modeContinuousV => 'تمرير متصل';

  @override
  String get searchInBook => 'بحث في الكتاب';

  @override
  String get exactPhrase => 'عبارة كاملة';

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String get deselectAll => 'إلغاء تحديد الكل';

  @override
  String get highlight => 'تمييز';

  @override
  String get removeHighlight => 'إزالة التمييز';

  @override
  String get addNote => 'إضافة ملاحظة';

  @override
  String get copyWithReference => 'نسخ مع المرجع';

  @override
  String get copiedCitation => 'تم نسخ الاقتباس';

  @override
  String get colorYellow => 'أصفر';

  @override
  String get colorGreen => 'أخضر';

  @override
  String get colorBlue => 'أزرق';

  @override
  String get colorPink => 'وردي';

  @override
  String get colorOrange => 'برتقالي';

  @override
  String get tabSettings => 'الإعدادات';

  @override
  String get textAppearance => 'مظهر النص';

  @override
  String get resetTextStyles => 'إعادة الافتراضي';

  @override
  String get bold => 'عريض';

  @override
  String get pickColor => 'اختر لونًا';

  @override
  String get colorHex => 'لون سداسي';

  @override
  String get roleBody => 'متن النص';

  @override
  String get roleTitle => 'العناوين';

  @override
  String get roleHonorific => 'الصيغ الثابتة (صلى الله عليه وسلم…)';

  @override
  String get roleQuran => 'آيات القرآن ﴿…﴾';

  @override
  String get rolePunctuation => 'علامات الترقيم';

  @override
  String get readerFont => 'خط القراءة';

  @override
  String get fontAmiri => 'أميري';

  @override
  String get fontScheherazade => 'شهرزاد الجديدة';

  @override
  String get fontSystem => 'خط النظام';

  @override
  String get fontSize => 'حجم الخط';

  @override
  String get notesTab => 'الملاحظات';

  @override
  String get notesEmpty => 'لا ملاحظات بعد';

  @override
  String get tocEmpty => 'لا فهرس';

  @override
  String get footnotes => 'الحواشي';

  @override
  String notePageLabel(String page) {
    return 'ص $page';
  }

  @override
  String get downloadsActive => 'جاري التنزيل';

  @override
  String get downloadsFailed => 'فشل';

  @override
  String get downloadsCompleted => 'مكتمل';

  @override
  String get downloadsEmpty => 'لا شيء هنا';

  @override
  String get redownload => 'إعادة التنزيل';

  @override
  String get confirmBulkDelete => 'حذف الكتب المحددة من الجهاز؟';

  @override
  String get libraryAllBooks => 'كل الكتب';

  @override
  String get back => 'رجوع';

  @override
  String get brandName => 'iSHAMELA';

  @override
  String get unavailableForDownload => 'غير متاح للتنزيل';

  @override
  String sectionWithCount(String label, int count) {
    return '$label · $count';
  }

  @override
  String downloadSelectedCount(int count) {
    return 'نزّل المحدد ($count)';
  }

  @override
  String get continueReading => 'متابعة القراءة';

  @override
  String get libraryEmptyHint =>
      'مكتبتك فارغة بعد — تصفح الفهرس ونزّل أول كتاب';

  @override
  String get browseCatalog => 'تصفح الفهرس';

  @override
  String get readingTheme => 'سمة القراءة';

  @override
  String get atmospherePaper => 'ورق';

  @override
  String get atmosphereSepia => 'سيبيا';

  @override
  String get atmosphereNight => 'ليلي';

  @override
  String get jumpToPageTitle => 'الانتقال إلى صفحة';

  @override
  String get completedToday => 'اكتمل اليوم';

  @override
  String activeDownloadsCount(int count) {
    return '$count جارية';
  }

  @override
  String get catalogStaleAction => 'حدّث الآن';

  @override
  String catalogStaleDays(int days) {
    return 'آخر تحديث قبل $days يومًا — حدّث الآن';
  }

  @override
  String volumesCount(int count) {
    return '$count أجزاء';
  }

  @override
  String get copyBibliography => 'نسخ التوثيق';

  @override
  String get historyTitle => 'سجل القراءة';

  @override
  String get historyClear => 'مسح السجل';

  @override
  String get historyClearConfirm => 'سيُحذف سجل القراءة نهائيًا.';

  @override
  String get historyEmpty => 'لم تقرأ شيئًا بعد — افتح كتابًا من مكتبتك';

  @override
  String get historyLink => 'السجل';

  @override
  String minutesAgo(int count) {
    return 'قبل $count دقيقة';
  }

  @override
  String hoursAgo(int count) {
    return 'قبل $count ساعة';
  }

  @override
  String daysAgo(int count) {
    return 'قبل $count يوم';
  }

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get older => 'أقدم';

  @override
  String get removeFromHistory => 'إزالة من السجل';

  @override
  String get notInstalled => 'غير مثبّت';

  @override
  String get bookmarks => 'العلامات';

  @override
  String bookmarkAdded(String page) {
    return 'أُضيفت علامة · ص $page';
  }

  @override
  String get bookmarkRemoved => 'أُزيلت العلامة';

  @override
  String get renameBookmark => 'إعادة تسمية العلامة';

  @override
  String get bookmarksEmpty => 'لا علامات بعد — اضغط رمز العلامة أثناء القراءة';

  @override
  String get undo => 'تراجع';

  @override
  String get storage => 'التخزين';

  @override
  String storageUsed(String size, int count) {
    return 'المستخدم: $size ($count كتابًا)';
  }

  @override
  String storageAvailable(String size) {
    return 'المتاح على الجهاز: $size';
  }

  @override
  String get manageStorage => 'إدارة التخزين';

  @override
  String get calculatingSizes => 'يجري حساب الأحجام…';

  @override
  String uninstallSelected(int count) {
    return 'إلغاء تثبيت المحدد ($count)';
  }

  @override
  String uninstallConfirmSize(String size) {
    return 'سيحرر $size.';
  }

  @override
  String freeUpSpace(String used, String free) {
    return '$used مستخدمة · $free متاحة';
  }

  @override
  String get noInstalledBooks => 'لا كتب مثبّتة';

  @override
  String get languageAndApp => 'اللغة والتطبيق';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get aboutApp => 'حول التطبيق';

  @override
  String version(String version, String build) {
    return 'الإصدار $version ($build)';
  }

  @override
  String get buildCopied => 'تم نسخ الإصدار';

  @override
  String get licenses => 'تراخيص الطرف الثالث';

  @override
  String get datasetAttributionTitle => 'بيانات المكتبة';

  @override
  String get datasetAttributionBody =>
      'بيانات المكتبة الشاملة — مجموعة AuthenticIlm/Shamela4_Full_DB على HuggingFace. تُعرض النصوص كما وردت في المصدر.';

  @override
  String get sourceCode => 'شفرة المصدر';

  @override
  String get noConnection => 'لا اتصال بالإنترنت';

  @override
  String get searchScopeTitles => 'العناوين';

  @override
  String get searchScopeTexts => 'النصوص';

  @override
  String get minQueryHint => 'أدخل حرفين على الأقل';

  @override
  String searchingBooksProgress(int done, int total) {
    return 'جارٍ البحث في $done من $total كتابًا…';
  }

  @override
  String hitsCapped(int count) {
    return '$count+';
  }

  @override
  String get moreHitsInBook => 'عرض المزيد داخل الكتاب';

  @override
  String get libSearchEmpty => 'لا نتائج في مكتبتك';

  @override
  String get tryCatalogSearch => 'ابحث في الفهرس';

  @override
  String get searchFailedRetry => 'فشل البحث — انقر لإعادة المحاولة';

  @override
  String authorBooksCount(int count) {
    return '$count كتابًا';
  }

  @override
  String authorInstalledCount(int count) {
    return 'مثبّت $count';
  }

  @override
  String get showMore => 'المزيد';

  @override
  String get showLess => 'أقل';

  @override
  String get allBooks => 'الكل';

  @override
  String get installedOnly => 'المثبّتة';

  @override
  String get noInstalledForAuthor => 'لا كتب مثبّتة لهذا المؤلف';

  @override
  String get filterHint => 'تصفية…';

  @override
  String diedHijri(int year) {
    return 'ت $yearهـ';
  }

  @override
  String diedCE(int year) {
    return 'ت $yearم';
  }

  @override
  String get exportAnnotations => 'تصدير الملاحظات والتظليلات';

  @override
  String get exportNoAnnotationsHint => 'لا ملاحظات في هذا الكتاب';

  @override
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatText => 'نص';

  @override
  String get includeHighlights => 'التظليلات';

  @override
  String get includeNotes => 'الملاحظات';

  @override
  String get export => 'تصدير';

  @override
  String get exportDone => 'تم التصدير';

  @override
  String exportedOn(String date) {
    return 'صُدِّر في $date';
  }

  @override
  String notesFileHeading(String title) {
    return 'ملاحظات — $title';
  }

  @override
  String get noteLabel => 'ملاحظة';

  @override
  String downloadingBook(String title) {
    return 'جاري تنزيل «$title»';
  }

  @override
  String downloadingNBooks(int count) {
    return 'جاري تنزيل $count كتب';
  }

  @override
  String get viewDownloads => 'عرض';

  @override
  String downloadCompleteSnack(String title) {
    return 'اكتمل تنزيل «$title»';
  }

  @override
  String get open => 'فتح';

  @override
  String downloadFailedSnack(String title) {
    return 'تعذّر تنزيل «$title»';
  }

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String alreadyInstalled(String title) {
    return '«$title» مثبّت مسبقاً';
  }

  @override
  String get preparingLibrary => 'يجري تجهيز المكتبة…';

  @override
  String get appTagline => 'مكتبتك في العلوم الشرعية — دون اتصال';

  @override
  String get startReading => 'ابدأ القراءة';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get homeGreeting => 'السلام عليكم';

  @override
  String homeGreetingNamed(String name) {
    return 'أهلًا، $name';
  }

  @override
  String get homeHijriApprox => 'تقريبًا';

  @override
  String get homeContinueReading => 'متابعة القراءة';

  @override
  String homeContinueA11y(String title, String part, String page) {
    return 'متابعة قراءة $title، الجزء $part، الصفحة $page';
  }

  @override
  String homeBookCrumb(String book, String section) {
    return 'كتاب $book · باب $section';
  }

  @override
  String homeVolPage(String vol, String page) {
    return 'ج $vol · ص $page';
  }

  @override
  String homePageOnly(String page) {
    return 'ص $page';
  }

  @override
  String homePercent(String pct) {
    return '٪$pct';
  }

  @override
  String get homeStreakDays => 'أيام متتالية';

  @override
  String get homeWeeklyMinutes => 'دقائق هذا الأسبوع';

  @override
  String get homeWeeklyPages => 'صفحات هذا الأسبوع';

  @override
  String get homeRecentHistory => 'آخر القراءات';

  @override
  String get homeViewAll => 'عرض الكل';

  @override
  String get homeQuickBookmarks => 'العلامات';

  @override
  String get homeQuickNotes => 'ملاحظاتي';

  @override
  String get homeSyncBanner => 'سجّل الدخول لمزامنة قراءاتك عبر أجهزتك';

  @override
  String get homeSyncBannerCta => 'تسجيل الدخول';

  @override
  String get homeEmptyTitle => 'ابدأ رحلتك مع المكتبة';

  @override
  String get homeEmptyCta => 'تصفَّح الفهرس';

  @override
  String get homeBookNotDownloaded => 'الكتاب غير منزّل';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileGuest => 'ضيف';

  @override
  String get profileGuestCopy =>
      'أنت تستخدم التطبيق بدون حساب — بياناتك محفوظة على هذا الجهاز فقط';

  @override
  String get profileSignInCta => 'تسجيل الدخول أو إنشاء حساب';

  @override
  String get profileEditName => 'تعديل الاسم';

  @override
  String get profileEditNameHint => 'الاسم (١–٤٠ حرفًا)';

  @override
  String get profileEditNameSave => 'حفظ';

  @override
  String get profileEditNameSaved => 'تم تحديث الاسم';

  @override
  String get profileEditNameInvalid => 'الاسم يجب أن يكون بين ١ و ٤٠ حرفًا';

  @override
  String get profileLifetimeBooks => 'كتب بدأتها';

  @override
  String get profileLifetimePages => 'صفحات مقروءة';

  @override
  String get profileLifetimeMinutes => 'دقائق القراءة';

  @override
  String get profileLongestStreak => 'أطول سلسلة أيام';

  @override
  String get profileSync => 'المزامنة';

  @override
  String profileLastSynced(String relative) {
    return 'آخر مزامنة: $relative';
  }

  @override
  String get profileNeverSynced => 'لم تتم المزامنة بعد';

  @override
  String get profileSyncNow => 'مزامنة الآن';

  @override
  String get profileSyncing => 'جارٍ مزامنة بياناتك…';

  @override
  String get profileSyncCellular => 'المزامنة عبر بيانات الهاتف';

  @override
  String get profileAutoDownload => 'تنزيل كتب مكتبتي تلقائيًا';

  @override
  String get librarySyncSection => 'مزامنة المكتبة';

  @override
  String get libraryWaitingWifi => 'بانتظار شبكة Wi-Fi';

  @override
  String get librarySetupTitle => 'تنزيل مكتبتك';

  @override
  String librarySetupBody(String count, String size) {
    return '$count كتابًا · $size';
  }

  @override
  String get libraryDownloadAll => 'تنزيل الكل';

  @override
  String get libraryChoose => 'اختيار';

  @override
  String get libraryLater => 'لاحقًا';

  @override
  String libraryStorageShort(String size) {
    return 'المساحة غير كافية لتنزيل مكتبتك ($size مطلوبة)';
  }

  @override
  String get libraryChooseBooks => 'اختيار الكتب';

  @override
  String get libraryManageStorage => 'إدارة التخزين';

  @override
  String get libraryRemoveDevice => 'إزالة من هذا الجهاز';

  @override
  String get libraryRemoveAll => 'إزالة من كل الأجهزة';

  @override
  String get libraryUnavailable => 'غير متوفر حاليًا';

  @override
  String get profileSyncError => 'تعذّرت المزامنة — أعد المحاولة';

  @override
  String get profileShortcutStorage => 'إدارة التخزين';

  @override
  String get profileShortcutHistory => 'سجل القراءة';

  @override
  String get profileShortcutBookmarks => 'العلامات';

  @override
  String get profileShortcutNotes => 'ملاحظاتي';

  @override
  String get profileShortcutSettings => 'الإعدادات';

  @override
  String get profileChangePassword => 'تغيير كلمة المرور';

  @override
  String get profileCurrentPassword => 'كلمة المرور الحالية';

  @override
  String get profileNewPassword => 'كلمة المرور الجديدة';

  @override
  String get profileConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get profilePasswordChanged => 'تم تغيير كلمة المرور';

  @override
  String get profilePasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get profileSignOut => 'تسجيل الخروج';

  @override
  String get profileSignOutConfirm => 'سيبقى سجلك وملاحظاتك على هذا الجهاز';

  @override
  String get profileDeleteAccount => 'حذف الحساب';

  @override
  String get profileDeleteExplain =>
      'سيُحذف حسابك السحابي وجميع البيانات المتزامنة. تبقى بياناتك المحلية على هذا الجهاز ما لم تفعّل الخيار أدناه.';

  @override
  String get profileDeleteWipeLocal => 'احذف بياناتي من هذا الجهاز أيضًا';

  @override
  String get profileDeleteTypeConfirm => 'اكتب «حذف» للتأكيد';

  @override
  String get profileDeleteConfirmWord => 'حذف';

  @override
  String get profileDeleteDone => 'تم حذف الحساب';

  @override
  String get profileDeleteFailed => 'تعذّر حذف الحساب — أعد المحاولة';

  @override
  String get profileAccount => 'الحساب';

  @override
  String get bookmarksListTitle => 'العلامات';

  @override
  String get notesListTitle => 'ملاحظاتي';

  @override
  String get notesListEmpty => 'لا ملاحظات بعد — أضف ملاحظة أثناء القراءة';

  @override
  String get authValueCopy =>
      'سجّل الدخول لمزامنة قراءاتك وملاحظاتك عبر أجهزتك';

  @override
  String get authContinueApple => 'متابعة عبر Apple';

  @override
  String get authContinueGoogle => 'متابعة عبر Google';

  @override
  String get authContinueEmail => 'البريد الإلكتروني';

  @override
  String get authContinueGuest => 'متابعة بدون حساب';

  @override
  String get authSignInTitle => 'تسجيل الدخول';

  @override
  String get authSignUpTitle => 'إنشاء حساب';

  @override
  String get authSignIn => 'تسجيل الدخول';

  @override
  String get authSignUp => 'إنشاء حساب';

  @override
  String get authCreateAccount => 'إنشاء حساب';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authForgotTitle => 'استعادة كلمة المرور';

  @override
  String get authForgotCopy => 'سنرسل رمزًا مكوَّنًا من ٦ أرقام إلى بريدك';

  @override
  String get authForgotSuccess => 'إن كان البريد مسجلًا لدينا فسيصلك الرمز';

  @override
  String get authSendCode => 'إرسال الرمز';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authNewPassword => 'كلمة المرور الجديدة';

  @override
  String get authConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get authDisplayName => 'الاسم';

  @override
  String get authFieldRequired => 'مطلوب';

  @override
  String get authInvalidEmail => 'بريد غير صالح';

  @override
  String get authPasswordTooShort => 'كلمة المرور ٨ أحرف على الأقل';

  @override
  String get authPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get authPasswordStrengthWeak => 'ضعيفة';

  @override
  String get authPasswordStrengthOk => 'مقبولة';

  @override
  String get authPasswordStrengthStrong => 'قوية';

  @override
  String get authPasswordChanged => 'تم تغيير كلمة المرور';

  @override
  String get authMustAcceptTerms => 'يجب الموافقة على السياسة والشروط';

  @override
  String get authAcceptPrefix => 'أوافق على';

  @override
  String get authAcceptAnd => 'و';

  @override
  String get authPrivacy => 'سياسة الخصوصية';

  @override
  String get authTerms => 'الشروط';

  @override
  String get authOtpTitle => 'أدخل الرمز';

  @override
  String authOtpCopy(String email) {
    return 'أُرسل رمز مكوَّن من ٦ أرقام إلى $email';
  }

  @override
  String get authVerifyCode => 'تحقق';

  @override
  String authOtpResendIn(String time) {
    return 'إعادة الإرسال بعد $time';
  }

  @override
  String get authOtpResend => 'إعادة الإرسال';

  @override
  String get authOtpResent => 'أُرسل الرمز';

  @override
  String get authOtpWrong => 'الرمز غير صحيح';

  @override
  String get authOtpExpired => 'انتهت صلاحية الرمز — اطلب رمزًا جديدًا';

  @override
  String get authOtpLocked => 'محاولات كثيرة — اطلب رمزًا جديدًا';

  @override
  String get authResetTitle => 'كلمة مرور جديدة';

  @override
  String get authSavePassword => 'حفظ كلمة المرور';

  @override
  String get authWelcomeVerified => 'مرحبًا — تم التحقق من حسابك';

  @override
  String get authWrongCredentials => 'البريد أو كلمة المرور غير صحيحة';

  @override
  String get authEmailAlreadyInUse => 'البريد مستخدم مسبقًا';

  @override
  String get authWeakPassword => 'كلمة المرور ضعيفة جدًا';

  @override
  String get authTooManyRequests => 'محاولات كثيرة — حاول لاحقًا';

  @override
  String get authNetworkError => 'خطأ في الشبكة — أعد المحاولة';

  @override
  String get authRequiresRecentLogin => 'سجّل الدخول مجددًا للمتابعة';

  @override
  String get authSessionExpired => 'انتهت الجلسة، سجّل الدخول من جديد للمزامنة';

  @override
  String get authUnavailable => 'تسجيل الدخول غير متاح حاليًا';

  @override
  String get authGenericError => 'حدث خطأ ما';

  @override
  String get authSyncInProgress => 'جارٍ مزامنة بياناتك…';

  @override
  String get authSyncFailed => 'تعذّرت المزامنة — ستُعاد لاحقًا';
}
