import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_strings.dart';
import '../providers/app_providers.dart';

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  static const english = Locale('en', 'IN');
  static const hindi = Locale('hi', 'IN');

  @override
  Locale build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(AppStrings.localeKey);

    return switch (stored) {
      'hi' => hindi,
      _ => english,
    };
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppStrings.localeKey, locale.languageCode);
  }
}
