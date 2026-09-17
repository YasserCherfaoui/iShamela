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
}
