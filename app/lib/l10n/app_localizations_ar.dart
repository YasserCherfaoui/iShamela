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
}
