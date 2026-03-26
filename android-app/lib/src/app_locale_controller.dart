import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import 'settings_store.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController({SettingsStore? settingsStore})
    : _settingsStore = settingsStore ?? SettingsStore.instance;

  final SettingsStore _settingsStore;
  Locale _locale = const Locale('tr');

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  Future<void> load() async {
    final languageCode = await _settingsStore.loadLanguageCode();
    _locale = Locale(_normalize(languageCode));
  }

  Future<void> setLanguageCode(String languageCode) async {
    final normalized = _normalize(languageCode);
    if (normalized == _locale.languageCode) {
      return;
    }
    await _settingsStore.setLanguageCode(normalized);
    _locale = Locale(normalized);
    notifyListeners();
  }

  AppLocalizations get strings => AppLocalizations.lookup(_locale.languageCode);

  String _normalize(String? languageCode) => switch (languageCode?.toLowerCase()) {
    'en' => 'en',
    'ru' => 'ru',
    'tk' => 'tr',
    _ => 'tr',
  };
}
