/// App-wide configuration sourced from --dart-define flags.
///
/// Defaults are safe placeholders; production builds must pass real keys via
/// `flutter run --dart-define=GOOGLE_MAPS_KEY_WEB=... ` etc.
class Env {
  static const String appName = 'Momentō';
  static const String domain = 'momento.community';
  static const String supportEmail = 'info@momento.community';
  static const String bundleId = 'community.momento.app';

  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'momento-b23c0');

  static const String functionsRegion = 'europe-west1';

  static const String googleMapsKeyWeb =
      String.fromEnvironment('GOOGLE_MAPS_KEY_WEB');
  static const String googleMapsKeyAndroid =
      String.fromEnvironment('GOOGLE_MAPS_KEY_ANDROID');
  static const String googleMapsKeyIOS =
      String.fromEnvironment('GOOGLE_MAPS_KEY_IOS');

  static const int freemiumLimit = 5;
  static const double pricePerDayEur = 5.0;
  static const int maxMomentoDurationDays = 5;
  static const double conflictRadiusMeters = 50.0;

  /// When true, screens read the in-memory mock fixture instead of Firestore.
  /// Pass `--dart-define=USE_MOCK_DATA=true` in dev runs without seeded data.
  static const bool useMockData =
      bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);
}
