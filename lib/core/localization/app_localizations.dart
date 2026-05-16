import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en', 'IN'),
    Locale('hi', 'IN'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context.');
    return localizations!;
  }

  bool get isHindi => locale.languageCode == 'hi';

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'RentFlow',
      'overview': 'Overview',
      'rooms': 'Rooms',
      'payments': 'Payments',
      'expenses': 'Expenses',
      'settings': 'Settings',
      'offlineMode': 'Offline mode. Live sync is paused and cached data is being shown.',
      'goodMorning': 'Good morning',
      'latestRentOverview': 'Here is your latest rent overview.',
      'totalCollected': 'Total collected',
      'pendingThisMonth': '{amount} is still pending this month.',
      'paymentQr': 'Payment QR',
      'openQr': 'Open QR',
      'paymentQrCompactMessage': 'Keep your family collection QR ready for quick walk-in payments.',
      'roomStatus': 'Room status',
      'viewAll': 'View all',
      'unableToLoadDashboard': 'Unable to load dashboard',
      'retry': 'Retry',
      'reports': 'Reports',
      'reportsAndExports': 'Reports and exports',
      'reportsOverview': 'Review monthly collection, yearly trends, pending dues, and expense mix from one place.',
      'filters': 'Filters',
      'filtersSubtitle': 'Use a month for collection and expense snapshots, and a year for the income trend.',
      'monthlyCollection': 'Monthly collection',
      'exportPdf': 'Export PDF',
      'collected': 'Collected',
      'pending': 'Pending',
      'partialRooms': 'Partial rooms',
      'fullyPaidRooms': 'Fully paid rooms',
      'yearlyIncomeSummary': 'Yearly income summary',
      'collectedVsPending': 'Collected vs pending for {year}',
      'incomePulse': 'Income pulse',
      'incomePulseSubtitle': 'A better read of momentum, weakest months, and collection quality.',
      'yearTotal': 'Year total',
      'bestMonth': 'Best month',
      'pendingLoad': 'Pending load',
      'monthlyPerformance': 'Monthly performance',
      'monthlyPerformanceSubtitle': 'Collected and pending side by side for every month.',
      'dueReport': 'Due report',
      'dueReportSubtitle': 'Rooms with the largest remaining amounts are surfaced first.',
      'roomsNeedAttention': 'Rooms that need attention',
      'roomsNeedAttentionSubtitle': '{count} rooms still need follow-up this cycle.',
      'noOutstandingDues': 'No outstanding dues',
      'allSettled': 'Every active room is fully settled for the current cycle.',
      'expenseReport': 'Expense report',
      'expenseReportSubtitle': 'Expense distribution for {month}',
      'expenseMix': 'Expense mix',
      'expenseMixSubtitle': 'See where this month\'s outflow is concentrated.',
      'noExpenses': 'No expenses for this month',
      'noExpensesSubtitle': 'Once expenses are recorded, category totals will appear here automatically.',
      'entriesCount': '{count} entries',
      'shareReportText': 'RentFlow monthly collection report for {month}',
      'exportFailed': 'Unable to export report: {error}',
      'loadReportsFailed': 'Unable to load reports.',
      'noYearlyData': 'No yearly data yet',
      'noYearlyDataSubtitle': 'Once payments are recorded, the month-by-month trend will appear here.',
      'settingsHeadline': 'Preferences and family access',
      'preferences': 'Preferences',
      'securityAndAppearance': 'Security and appearance',
      'darkMode': 'Dark mode',
      'darkModeSubtitle': 'Switch between light and dark themes',
      'biometricLock': 'Biometric lock',
      'biometricAvailable': 'Fingerprint or face unlock at sign-in',
      'biometricUnavailable': 'Biometric authentication is unavailable on this device',
      'language': 'Language',
      'languageSubtitle': 'Choose how RentFlow appears across the app',
      'english': 'English',
      'hindi': 'Hindi',
      'admin': 'Admin',
      'familyManagement': 'Family management',
      'manageUsers': 'Manage users',
      'manageUsersSubtitle': 'Add, edit, or deactivate family members',
      'activityLog': 'Activity log',
      'activityLogSubtitle': 'Review recent actions across the family',
      'logOut': 'Log out',
      'familyMember': 'Family member',
      'superAdmin': 'Super Admin',
      'familyRole': 'Family member',
      'collectByQr': 'Collect by QR',
      'showThisQr': 'Show this QR to the tenant',
      'saveAfterQr': 'Once the amount is received, save the rent update below.',
      'fullScreen': 'Full screen',
      'collectRentByQr': 'Collect rent by QR',
      'collectRentByQrSubtitle': 'Show this code to the tenant, confirm the transfer, then record the payment in RentFlow.',
      'familyCollectionQr': 'Family collection QR',
      'readyToScan': 'Ready to scan',
      'readyToScanSubtitle': 'Tap and pinch if you want to zoom in before the tenant scans it.',
      'bestUse': 'Best use',
      'simpleCollectionFlow': 'Simple collection flow',
      'step1Qr': 'Ask the tenant to scan the QR and finish the transfer.',
      'step2Qr': 'Confirm the payment message or UPI success screen.',
      'step3Qr': 'Record the amount in RentFlow so the whole family sees it immediately.',
      'paymentDate': 'Payment date',
      'unableToLoadRooms': 'Unable to load rooms',
      'noRoomsYet': 'No rooms yet',
      'vacant': 'Vacant',
    },
    'hi': {
      'appTitle': 'रेंटफ्लो',
      'overview': 'होम',
      'rooms': 'कमरे',
      'payments': 'भुगतान',
      'expenses': 'खर्च',
      'settings': 'सेटिंग्स',
      'offlineMode': 'ऑफलाइन मोड। लाइव सिंक रुका हुआ है और कैश किया गया डेटा दिखाया जा रहा है।',
      'goodMorning': 'सुप्रभात',
      'latestRentOverview': 'यह आपके किराये का ताज़ा सारांश है।',
      'totalCollected': 'कुल वसूली',
      'pendingThisMonth': 'इस महीने अभी {amount} बाकी है।',
      'paymentQr': 'पेमेंट QR',
      'openQr': 'QR खोलें',
      'paymentQrCompactMessage': 'किराया लेने के लिए परिवार का QR हमेशा तैयार रखें।',
      'roomStatus': 'कमरों की स्थिति',
      'viewAll': 'सब देखें',
      'unableToLoadDashboard': 'डैशबोर्ड लोड नहीं हो सका',
      'retry': 'फिर कोशिश करें',
      'reports': 'रिपोर्ट्स',
      'reportsAndExports': 'रिपोर्ट और एक्सपोर्ट',
      'reportsOverview': 'मासिक कलेक्शन, सालाना ट्रेंड, बकाया किराया और खर्च का पूरा दृश्य एक ही जगह देखें।',
      'filters': 'फ़िल्टर',
      'filtersSubtitle': 'कलेक्शन और खर्च के लिए महीना चुनें, और ट्रेंड के लिए साल चुनें।',
      'monthlyCollection': 'मासिक कलेक्शन',
      'exportPdf': 'PDF एक्सपोर्ट',
      'collected': 'वसूला गया',
      'pending': 'बाकी',
      'partialRooms': 'आंशिक कमरे',
      'fullyPaidRooms': 'पूरी तरह भरे कमरे',
      'yearlyIncomeSummary': 'सालाना आय सारांश',
      'collectedVsPending': '{year} के लिए वसूली बनाम बकाया',
      'incomePulse': 'आय की स्थिति',
      'incomePulseSubtitle': 'कौन-से महीने मजबूत या कमजोर रहे, यह जल्दी समझें।',
      'yearTotal': 'साल का कुल',
      'bestMonth': 'सबसे अच्छा महीना',
      'pendingLoad': 'कुल बकाया',
      'monthlyPerformance': 'मासिक प्रदर्शन',
      'monthlyPerformanceSubtitle': 'हर महीने की वसूली और बकाया साथ में देखें।',
      'dueReport': 'बकाया रिपोर्ट',
      'dueReportSubtitle': 'जिन कमरों में सबसे ज़्यादा राशि बाकी है, उन्हें ऊपर दिखाया गया है।',
      'roomsNeedAttention': 'ध्यान देने वाले कमरे',
      'roomsNeedAttentionSubtitle': 'इस चक्र में अभी {count} कमरों पर फॉलो-अप बाकी है।',
      'noOutstandingDues': 'कोई बकाया नहीं',
      'allSettled': 'सभी सक्रिय कमरों का किराया इस चक्र में पूरा हो चुका है।',
      'expenseReport': 'खर्च रिपोर्ट',
      'expenseReportSubtitle': '{month} के खर्च का वितरण',
      'expenseMix': 'खर्च का अनुपात',
      'expenseMixSubtitle': 'देखें कि इस महीने सबसे ज़्यादा खर्च कहाँ हुआ।',
      'noExpenses': 'इस महीने कोई खर्च नहीं',
      'noExpensesSubtitle': 'जैसे ही खर्च दर्ज होंगे, श्रेणीवार कुल राशि यहाँ दिखेगी।',
      'entriesCount': '{count} एंट्री',
      'shareReportText': '{month} के लिए RentFlow मासिक कलेक्शन रिपोर्ट',
      'exportFailed': 'रिपोर्ट एक्सपोर्ट नहीं हो सकी: {error}',
      'loadReportsFailed': 'रिपोर्ट्स लोड नहीं हो सकीं।',
      'noYearlyData': 'अभी सालाना डेटा नहीं है',
      'noYearlyDataSubtitle': 'जैसे ही भुगतान रिकॉर्ड होंगे, महीनेवार ट्रेंड यहाँ दिखेगा।',
      'settingsHeadline': 'पसंद और परिवार की पहुँच',
      'preferences': 'पसंद',
      'securityAndAppearance': 'सुरक्षा और रूप',
      'darkMode': 'डार्क मोड',
      'darkModeSubtitle': 'लाइट और डार्क थीम के बीच बदलें',
      'biometricLock': 'बायोमेट्रिक लॉक',
      'biometricAvailable': 'साइन-इन पर फिंगरप्रिंट या फेस अनलॉक',
      'biometricUnavailable': 'इस डिवाइस पर बायोमेट्रिक उपलब्ध नहीं है',
      'language': 'भाषा',
      'languageSubtitle': 'ऐप में RentFlow किस भाषा में दिखे, चुनें',
      'english': 'अंग्रेज़ी',
      'hindi': 'हिंदी',
      'admin': 'एडमिन',
      'familyManagement': 'परिवार प्रबंधन',
      'manageUsers': 'यूज़र प्रबंधन',
      'manageUsersSubtitle': 'परिवार के लोगों को जोड़ें, बदलें या निष्क्रिय करें',
      'activityLog': 'एक्टिविटी लॉग',
      'activityLogSubtitle': 'परिवार की हाल की गतिविधियाँ देखें',
      'logOut': 'लॉग आउट',
      'familyMember': 'परिवार सदस्य',
      'superAdmin': 'सुपर एडमिन',
      'familyRole': 'परिवार सदस्य',
      'collectByQr': 'QR से भुगतान लें',
      'showThisQr': 'यह QR किरायेदार को दिखाएँ',
      'saveAfterQr': 'राशि मिलते ही नीचे किराये का अपडेट सेव करें।',
      'fullScreen': 'फुल स्क्रीन',
      'collectRentByQr': 'QR से किराया लें',
      'collectRentByQrSubtitle': 'किरायेदार को यह कोड दिखाएँ, ट्रांसफर की पुष्टि करें, फिर RentFlow में भुगतान दर्ज करें।',
      'familyCollectionQr': 'परिवार का कलेक्शन QR',
      'readyToScan': 'स्कैन के लिए तैयार',
      'readyToScanSubtitle': 'ज़रूरत हो तो स्कैन से पहले टैप करके ज़ूम करें।',
      'bestUse': 'कैसे उपयोग करें',
      'simpleCollectionFlow': 'सरल कलेक्शन प्रक्रिया',
      'step1Qr': 'किरायेदार से QR स्कैन कराकर ट्रांसफर पूरा करवाएँ।',
      'step2Qr': 'पेमेंट मैसेज या UPI सफलता स्क्रीन देखकर पुष्टि करें।',
      'step3Qr': 'राशि को RentFlow में दर्ज करें ताकि परिवार के सभी लोग तुरंत देख सकें।',
      'paymentDate': 'भुगतान की तारीख',
      'unableToLoadRooms': 'कमरे लोड नहीं हो सके',
      'noRoomsYet': 'अभी कोई कमरा नहीं है',
      'vacant': 'खाली',
    },
  };

  String tr(String key, {Map<String, String> params = const {}}) {
    final languageCode = _localizedValues.containsKey(locale.languageCode)
        ? locale.languageCode
        : 'en';
    var value = _localizedValues[languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;

    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }

    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
