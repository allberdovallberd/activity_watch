import 'dart:math';

import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

import "app_config.dart";

class AppSettings {
  const AppSettings({
    required this.deviceId,
    required this.clientInstanceId,
    required this.displayName,
    required this.backendBaseUrl,
    required this.deviceToken,
    required this.languageCode,
    required this.hasSettingsPassword,
  });

  final String deviceId;
  final String clientInstanceId;
  final String displayName;
  final String backendBaseUrl;
  final String deviceToken;
  final String languageCode;
  final bool hasSettingsPassword;
}

class SettingsStore {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _deviceIdKey = 'device_id';
  static const _clientInstanceIdKey = 'client_instance_id';
  static const _displayNameKey = 'display_name';
  static const _backendUrlKey = 'backend_url';
  static const _deviceTokenKey = 'device_token';
  static const _languageCodeKey = 'language_code';
  static const _settingsPasswordKey = 'settings_password';
  static const MethodChannel _nativeChannel = MethodChannel(
    'usage_collector/native',
  );
  SharedPreferences? _prefs;
  AppSettings? _cached;
  int _lastLoadMs = 0;
  static const _cacheTtlMs = 1500;

  Future<SharedPreferences> _getPrefs() async {
    final existing = _prefs;
    if (existing != null) {
      return existing;
    }
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    return prefs;
  }

  void _invalidateCache() {
    _cached = null;
    _lastLoadMs = 0;
  }

  Future<AppSettings> load() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cached = _cached;
    if (cached != null && nowMs - _lastLoadMs < _cacheTtlMs) {
      return cached;
    }
    final prefs = await _getPrefs();
    // Background service and foreground UI can run in different isolates.
    // Reload before reading so backend URL/device settings changed in the UI
    // are visible to background sync immediately.
    await prefs.reload();
    final deviceId = (prefs.getString(_deviceIdKey) ?? '').trim().toUpperCase();
    var clientInstanceId = prefs.getString(_clientInstanceIdKey) ?? '';
    var deviceToken = prefs.getString(_deviceTokenKey) ?? '';
    final isPlaceholder = deviceToken.isNotEmpty && deviceToken == clientInstanceId;
    if (deviceToken.isEmpty || isPlaceholder) {
      final fetched = await _fetchDeviceToken();
      if (fetched.isNotEmpty) {
        deviceToken = fetched;
        await prefs.setString(_deviceTokenKey, deviceToken);
      } else if (deviceToken.isEmpty) {
        deviceToken = '';
      }
    }
    if (clientInstanceId.isEmpty) {
      clientInstanceId = _generateClientInstanceId();
      await prefs.setString(_clientInstanceIdKey, clientInstanceId);
    }
    var backendBaseUrl = _normalizeUrl(
      prefs.getString(_backendUrlKey) ?? AppConfig.defaultBackendBaseUrl,
    );
    if (backendBaseUrl.isEmpty) {
      backendBaseUrl = _normalizeUrl(AppConfig.defaultBackendBaseUrl);
    }
    final settings = AppSettings(
      deviceId: deviceId,
      clientInstanceId: clientInstanceId,
      displayName: prefs.getString(_displayNameKey) ?? '',
      backendBaseUrl: backendBaseUrl,
      deviceToken: deviceToken,
      languageCode: _normalizeLanguageCode(prefs.getString(_languageCodeKey)),
      hasSettingsPassword: (prefs.getString(_settingsPasswordKey) ?? '').isNotEmpty,
    );
    _cached = settings;
    _lastLoadMs = nowMs;
    return settings;
  }

  Future<void> save({
    required String deviceId,
    required String displayName,
    String? backendBaseUrl,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(_deviceIdKey, deviceId.trim().toUpperCase());
    await prefs.setString(_displayNameKey, displayName);
    if (backendBaseUrl != null) {
      final normalized = _normalizeUrl(backendBaseUrl);
      if (normalized.isEmpty) {
        await prefs.remove(_backendUrlKey);
      } else {
        await prefs.setString(_backendUrlKey, normalized);
      }
    }
    _invalidateCache();
  }

  Future<void> setBackendBaseUrl(String backendBaseUrl) async {
    final prefs = await _getPrefs();
    final normalized = _normalizeUrl(backendBaseUrl);
    if (normalized.isEmpty) {
      await prefs.remove(_backendUrlKey);
    } else {
      await prefs.setString(_backendUrlKey, normalized);
    }
    _invalidateCache();
  }

  Future<void> clearDeviceId() async {
    final prefs = await _getPrefs();
    await prefs.setString(_deviceIdKey, '');
    _invalidateCache();
  }

  Future<void> clearConfig() async {
    final prefs = await _getPrefs();
    await prefs.setString(_deviceIdKey, '');
    await prefs.setString(_displayNameKey, '');
    _invalidateCache();
  }

  Future<String> loadLanguageCode() async {
    final prefs = await _getPrefs();
    return _normalizeLanguageCode(prefs.getString(_languageCodeKey));
  }

  Future<void> setLanguageCode(String languageCode) async {
    final prefs = await _getPrefs();
    await prefs.setString(_languageCodeKey, _normalizeLanguageCode(languageCode));
    _invalidateCache();
  }

  Future<bool> hasSettingsPassword() async {
    final prefs = await _getPrefs();
    return (prefs.getString(_settingsPasswordKey) ?? '').isNotEmpty;
  }

  Future<bool> verifySettingsPassword(String password) async {
    final prefs = await _getPrefs();
    final current = prefs.getString(_settingsPasswordKey) ?? '';
    return current.isNotEmpty && current == password;
  }

  Future<void> setSettingsPassword(String password) async {
    final prefs = await _getPrefs();
    await prefs.setString(_settingsPasswordKey, password);
    _invalidateCache();
  }

  Future<void> clearSettingsPassword() async {
    final prefs = await _getPrefs();
    await prefs.remove(_settingsPasswordKey);
    _invalidateCache();
  }

  String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  String _normalizeLanguageCode(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'en' => 'en',
      'ru' => 'ru',
      'tk' => 'tr',
      _ => 'tr',
    };
  }

  String _generateClientInstanceId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final codeUnits = List.generate(
      16,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    );
    return String.fromCharCodes(codeUnits);
  }

  Future<String> _fetchDeviceToken() async {
    try {
      final token = await _nativeChannel.invokeMethod<String>('getDeviceToken');
      return token?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }
}
