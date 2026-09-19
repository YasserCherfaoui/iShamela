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
}
