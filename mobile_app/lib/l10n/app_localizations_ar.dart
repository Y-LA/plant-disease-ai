// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'اكتشاف أمراض النبات';

  @override
  String get welcomeMessage => 'مرحباً بك';

  @override
  String welcomeUser(String name) {
    return 'مرحباً بك، $name';
  }

  @override
  String get intelligentDiagnosisSystem => 'نظام التشخيص الذكي';

  @override
  String get createdBy => 'تم الإعداد بواسطة:';

  @override
  String get supervisedBy => 'إشراف:\nأ.د. هبة النمر';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get signup => 'إنشاء حساب جديد';

  @override
  String get guestLogin => 'الدخول كضيف';

  @override
  String get pleaseLogin => 'الرجاء تسجيل الدخول للمتابعة';

  @override
  String get scan => 'فحص';

  @override
  String get history => 'السجل';

  @override
  String get settings => 'الإعدادات';

  @override
  String get theme => 'المظهر';

  @override
  String get lightTheme => 'فاتح';

  @override
  String get darkTheme => 'داكن';

  @override
  String get systemTheme => 'النظام';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get homeDescription =>
      'التقط صورة واضحة لورقة نبات واحدة. سنقوم بتشخيص المرض واقتراح العلاج.';

  @override
  String get tipsTitle => 'نصائح لأفضل النتائج';

  @override
  String get tip1 => 'استخدم إضاءة جيدة (بدون ظلال قوية).';

  @override
  String get tip2 => 'اجعل الورقة في المنتصف وتأكد من وضوحها.';

  @override
  String get tip3 => 'تجنب تصوير عدة أوراق في صورة واحدة.';

  @override
  String get tip4 => 'يفضل استخدام خلفية سادة إن أمكن.';

  @override
  String get camera => 'الكاميرا';

  @override
  String get gallery => 'المعرض';

  @override
  String get privacyNotice => 'الخصوصية: تُستخدم الصور للتحليل فقط.';

  @override
  String get errorInvalidEmail => 'صيغة البريد الإلكتروني غير صحيحة.';

  @override
  String get errorUserNotFound =>
      'لم يتم العثور على مستخدم بهذا البريد الإلكتروني.';

  @override
  String get errorWrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String get errorEmailAlreadyInUse =>
      'هناك حساب موجود بالفعل بهذا البريد الإلكتروني.';

  @override
  String get errorWeakPassword => 'كلمة المرور ضعيفة جداً.';

  @override
  String get errorDefault => 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';

  @override
  String get errorTitle => 'خطأ';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get name => 'الاسم الكامل';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟ تسجيل الدخول';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟ إنشاء حساب';
}
