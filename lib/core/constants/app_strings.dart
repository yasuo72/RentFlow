class AppStrings {
  const AppStrings._();

  static const String appName = 'RentFlow';
  static const String tagline = 'Rent, Tracked. Family, Synced.';
  // Physical Android devices on the same Wi-Fi must use the machine's LAN IP.
  static const String apiBaseUrl = 'http://192.168.1.2:5000/api';
  static const String socketBaseUrl = 'http://192.168.1.2:5000';
  static const String authTokenKey = 'rentflow_auth_token';
  static const String themeKey = 'rentflow_theme_mode';
  static const String localeKey = 'rentflow_locale';
  static const String biometricKey = 'rentflow_biometric_enabled';
  static const String dashboardCacheKey = 'rentflow_dashboard_cache';
  static const String roomsCacheKey = 'rentflow_rooms_cache';
  static const String paymentsCacheKey = 'rentflow_payments_cache';
  static const String paymentQrAsset = 'assets/image.png';
}
