// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Plant Disease Detector';

  @override
  String get welcomeMessage => 'Welcome';

  @override
  String welcomeUser(String name) {
    return 'Welcome, $name';
  }

  @override
  String get intelligentDiagnosisSystem => 'Intelligent Diagnosis System';

  @override
  String get createdBy => 'Created by:';

  @override
  String get supervisedBy => 'Supervised by:\nProf. Heba Elnemr';

  @override
  String get login => 'Login';

  @override
  String get signup => 'Create New Account';

  @override
  String get guestLogin => 'Login as Guest';

  @override
  String get pleaseLogin => 'Please login to continue';

  @override
  String get scan => 'Scan';

  @override
  String get history => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get theme => 'Theme';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get systemTheme => 'System';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get homeDescription =>
      'Take a clear photo of a single leaf. We will predict the disease and suggest treatment.';

  @override
  String get tipsTitle => 'Tips for best results';

  @override
  String get tip1 => 'Use good lighting (no harsh shadows).';

  @override
  String get tip2 => 'Keep the leaf centered and in focus.';

  @override
  String get tip3 => 'Avoid multiple leaves in one photo.';

  @override
  String get tip4 => 'Prefer plain background if possible.';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get privacyNotice =>
      'Privacy: Images are used only for analysis. (MVP placeholder)';

  @override
  String get errorInvalidEmail => 'The email address is badly formatted.';

  @override
  String get errorUserNotFound => 'No user found for that email.';

  @override
  String get errorWrongPassword => 'Wrong password provided for that user.';

  @override
  String get errorEmailAlreadyInUse =>
      'The account already exists for that email.';

  @override
  String get errorWeakPassword => 'The password provided is too weak.';

  @override
  String get errorDefault => 'An unexpected error occurred. Please try again.';

  @override
  String get errorTitle => 'Error';

  @override
  String get logout => 'Logout';

  @override
  String get name => 'Full Name';

  @override
  String get alreadyHaveAccount => 'Already have an account? Login';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Sign up';
}
