class AppStrings {
  const AppStrings._();

  static const String appName = 'RentFlow';
  static const String tagline = 'Rent, Tracked. Family, Synced.';
  static const String serverOrigin =
      'https://rentflow-production-1.up.railway.app';
  static const String apiBaseUrl = '$serverOrigin/api';
  static const String socketBaseUrl = serverOrigin;
  static const String paymentQrPublicUrl =
      '$serverOrigin/public/payment-qr.png';
  static const String authTokenKey = 'rentflow_auth_token';
  static const String themeKey = 'rentflow_theme_mode';
  static const String localeKey = 'rentflow_locale';
  static const String biometricKey = 'rentflow_biometric_enabled';
  static const String dashboardCacheKey = 'rentflow_dashboard_cache';
  static const String roomsCacheKey = 'rentflow_rooms_cache';
  static const String paymentsCacheKey = 'rentflow_payments_cache';
  static const String expensesCacheKey = 'rentflow_expenses_cache';
  static const String notificationLastSeenKey =
      'rentflow_notifications_seen_at';
  static const String paymentQrAsset = 'assets/image.png';
}
