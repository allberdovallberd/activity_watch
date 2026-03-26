import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import 'local_db.dart';
import 'settings_store.dart';

enum LinkStatus { success, emptyField, noSuchId, alreadyInUse, failed }

class LinkResult {
  const LinkResult(this.status, this.message);
  final LinkStatus status;
  final String message;
}

class _PostResult {
  const _PostResult({required this.response, required this.baseUrl});

  final http.Response response;
  final String baseUrl;
}

class SyncService {
  static const _lastRegisterMetaKey = 'last_register_ms';
  static const _lastAppsSyncMetaKey = 'last_apps_sync_ms';
  static const _appsInventoryChangedMetaKey = 'app_inventory_changed_ms';
  static const _registerIntervalMs = 0;
  static const _appsChunkSize = 60;
  static const _syncedCleanupMetaKey = 'last_synced_cleanup_ms';
  static const _lastHeartbeatMetaKey = 'last_heartbeat_ms';
  // Keep local history for 62 days.
  static const _syncedRetentionMs = 62 * 24 * 60 * 60 * 1000;
  static const _heartbeatIntervalMs = 20 * 1000;
  static final http.Client _client = http.Client();

  Future<AppLocalizations> _l10n() async {
    final languageCode = await SettingsStore.instance.loadLanguageCode();
    return AppLocalizations.lookup(languageCode);
  }

  Future<LinkResult> linkDevice({
    required String deviceId,
    required String displayName,
  }) async {
    final l10n = await _l10n();
    final normalizedId = deviceId.trim().toUpperCase();
    if (normalizedId.isEmpty) {
      return LinkResult(LinkStatus.emptyField, l10n('deviceIdRequired'));
    }
    final settings = await SettingsStore.instance.load();
    final baseUrl = settings.backendBaseUrl;
    final network = await hasNetwork();
    if (!network) {
      return LinkResult(LinkStatus.failed, l10n('noNetworkTryAgain'));
    }
    final register = await _registerResponse(
      preferredBaseUrl: baseUrl,
      deviceId: normalizedId,
      clientInstanceId: settings.clientInstanceId,
      deviceToken: settings.deviceToken,
      displayName: displayName,
    );
    final ok =
        register.response.statusCode >= 200 &&
        register.response.statusCode < 300;
    if (ok) {
      await SettingsStore.instance.save(
        deviceId: normalizedId,
        displayName: displayName,
        backendBaseUrl: register.baseUrl,
      );
      return LinkResult(LinkStatus.success, l10n('allSetDialog'));
    }
    final registerError = await _getLastRegisterError(
      preferredBaseUrl: baseUrl,
      deviceId: normalizedId,
      clientInstanceId: settings.clientInstanceId,
      deviceToken: settings.deviceToken,
      displayName: displayName,
    );
    if (registerError.contains('Unknown or inactive device ID')) {
      return LinkResult(LinkStatus.noSuchId, l10n('noSuchId'));
    }
    if (registerError.contains('already linked to another physical device')) {
      return LinkResult(LinkStatus.alreadyInUse, l10n('idAlreadyInUse'));
    }
    if (registerError.contains('blocked for this device ID')) {
      return LinkResult(LinkStatus.alreadyInUse, l10n('idAlreadyInUse'));
    }
    return LinkResult(LinkStatus.failed, l10n('somethingWentWrong'));
  }

  Future<bool> hasNetwork() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      return connectivity.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // If connectivity plugin isn't available in a background isolate, try anyway.
      return true;
    }
  }

  Future<String> syncOnce() async {
    final l10n = await _l10n();
    late final AppSettings settings;
    try {
      settings = await SettingsStore.instance.load();
    } catch (_) {
      return l10n('missingSettings');
    }
    var baseUrl = settings.backendBaseUrl;
    if (settings.deviceId.isEmpty) {
      return l10n('missingDeviceId');
    }

    final network = await hasNetwork();
    if (!network) {
      return l10n('noNetworkKeepingLocal');
    }

    final registerOk = await _registerIfDue(settings, baseUrl);
    if (!registerOk) {
      return l10n('registrationFailed');
    }
    baseUrl = (await SettingsStore.instance.load()).backendBaseUrl;

    final lastAppsSyncMs =
        await LocalDb.instance.getMetaInt(_lastAppsSyncMetaKey) ?? 0;
    final appsInventoryChangedMs =
        await LocalDb.instance.getMetaInt(_appsInventoryChangedMetaKey) ?? 0;
    final hasAnyApps = (await LocalDb.instance.countInstalledApps()) > 0;
    final shouldFullReplaceApps =
        appsInventoryChangedMs > lastAppsSyncMs ||
        (lastAppsSyncMs == 0 && hasAnyApps);
    final apps = shouldFullReplaceApps
        ? await LocalDb.instance.getInstalledApps()
        : await LocalDb.instance.getInstalledAppsChangedSince(lastAppsSyncMs);
    if (apps.isEmpty && !shouldFullReplaceApps) {
      // no-op, usage sync may still be needed
    } else {
      final appsSynced = await _syncApps(
        baseUrl: baseUrl,
        deviceId: settings.deviceId,
        clientInstanceId: settings.clientInstanceId,
        deviceToken: settings.deviceToken,
        apps: apps,
        fullReplace: shouldFullReplaceApps,
      );
      if (!appsSynced) {
        return l10n('appSyncFailed');
      }
      await LocalDb.instance.setMetaInt(
        _lastAppsSyncMetaKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      baseUrl = (await SettingsStore.instance.load()).backendBaseUrl;
    }

    var usageRows = await LocalDb.instance.getUnsyncedUsage(limit: 1000);
    if (usageRows.isEmpty) {
      final heartbeat = await _sendHeartbeatIfDue(settings, baseUrl);
      await _cleanupSyncedIfDue();
      if (heartbeat != null) {
        return heartbeat;
      }
      return apps.isEmpty ? l10n('noDataToSync') : l10n('appsSynced');
    }

    var syncedRows = 0;
    while (usageRows.isNotEmpty) {
      final payload = {
        'device_id': settings.deviceId,
        'client_instance_id': settings.clientInstanceId,
        'device_token': settings.deviceToken,
        'apps': const <Map<String, Object?>>[],
        'apps_full_replace': false,
        'apps_append': false,
        'usage_sessions': usageRows
            .map(
              (u) => {
                'package_name': u.packageName,
                'start_time': DateTime.fromMillisecondsSinceEpoch(
                  u.startMs,
                  isUtc: true,
                ).toIso8601String(),
                'end_time': DateTime.fromMillisecondsSinceEpoch(
                  u.endMs,
                  isUtc: true,
                ).toIso8601String(),
                'foreground_ms': u.foregroundMs,
              },
            )
            .toList(),
      };

      final result = await _postJsonWithFallback(
        preferredBaseUrl: baseUrl,
        path: '/api/v1/sync',
        payload: payload,
        timeout: const Duration(seconds: 90),
      );
      final response = result.response;
      baseUrl = result.baseUrl;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final serverError = _extractError(response.body);
        if (_isInvalidBindingError(serverError)) {
          await SettingsStore.instance.clearDeviceId();
          return l10n('deviceIdDisabled');
        }
        return l10n('syncFailedHttp', {'code': '${response.statusCode}'});
      }

      if (usageRows.isNotEmpty) {
        await LocalDb.instance.markUsageSynced(
          usageRows.map((e) => e.id!).toList(),
        );
        syncedRows += usageRows.length;
      }

      usageRows = await LocalDb.instance.getUnsyncedUsage(limit: 1000);
      if (syncedRows >= 5000) {
        break;
      }
    }

    await _cleanupSyncedIfDue();
    return l10n('syncedUsageRows', {'count': '$syncedRows'});
  }

  Future<String?> _sendHeartbeatIfDue(
    AppSettings settings,
    String baseUrl,
  ) async {
    final l10n = await _l10n();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastHeartbeat =
        await LocalDb.instance.getMetaInt(_lastHeartbeatMetaKey) ?? 0;
    if (nowMs - lastHeartbeat < _heartbeatIntervalMs) {
      return null;
    }
    final payload = {
      'device_id': settings.deviceId,
      'client_instance_id': settings.clientInstanceId,
      'device_token': settings.deviceToken,
      'apps': const <Map<String, Object?>>[],
      'apps_full_replace': false,
      'apps_append': false,
      'usage_sessions': const <Map<String, Object?>>[],
    };
    final response = (await _postJsonWithFallback(
      preferredBaseUrl: baseUrl,
      path: '/api/v1/sync',
      payload: payload,
      timeout: const Duration(seconds: 30),
    )).response;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return l10n('heartbeatFailedHttp', {'code': '${response.statusCode}'});
    }
    await LocalDb.instance.setMetaInt(_lastHeartbeatMetaKey, nowMs);
    return l10n('heartbeatOk');
  }

  Future<bool> _syncApps({
    required String baseUrl,
    required String deviceId,
    required String clientInstanceId,
    required String deviceToken,
    required List<InstalledAppRow> apps,
    required bool fullReplace,
  }) async {
    if (apps.isEmpty && !fullReplace) {
      return true;
    }
    final inventorySyncId = fullReplace
        ? DateTime.now().toUtc().toIso8601String()
        : null;

    if (apps.isEmpty && fullReplace) {
      final response = (await _postJsonWithFallback(
        preferredBaseUrl: baseUrl,
        path: '/api/v1/sync',
        payload: {
          'device_id': deviceId,
          'client_instance_id': clientInstanceId,
          'device_token': deviceToken,
          'apps': const <Map<String, Object?>>[],
          'apps_full_replace': true,
          'apps_append': false,
          'apps_replace_complete': true,
          'apps_inventory_sync_id': inventorySyncId,
          'usage_sessions': const <Map<String, Object?>>[],
        },
        timeout: const Duration(seconds: 90),
      )).response;
      return response.statusCode >= 200 && response.statusCode < 300;
    }

    for (var i = 0; i < apps.length; i += _appsChunkSize) {
      final chunk = apps.skip(i).take(_appsChunkSize).toList();
      final isLastChunk = i + _appsChunkSize >= apps.length;
      final response = (await _postJsonWithFallback(
        preferredBaseUrl: baseUrl,
        path: '/api/v1/sync',
        payload: {
          'device_id': deviceId,
          'client_instance_id': clientInstanceId,
          'device_token': deviceToken,
          'apps': chunk
              .map(
                (a) => {
                  'package_name': a.packageName,
                  'app_name': a.appName,
                  'icon_base64': a.iconBase64,
                  'is_system': a.isSystem,
                  'is_tracking': a.isTracking,
                },
              )
              .toList(),
          'apps_full_replace': fullReplace && i == 0,
          'apps_append': fullReplace && i > 0,
          'apps_replace_complete': fullReplace && isLastChunk,
          'apps_inventory_sync_id': inventorySyncId,
          'usage_sessions': const <Map<String, Object?>>[],
        },
        timeout: const Duration(seconds: 90),
      )).response;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final serverError = _extractError(response.body);
        if (_isInvalidBindingError(serverError)) {
          await SettingsStore.instance.clearDeviceId();
        }
        return false;
      }
    }
    return true;
  }

  Future<bool> _registerIfDue(AppSettings settings, String baseUrl) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastRegister =
        await LocalDb.instance.getMetaInt(_lastRegisterMetaKey) ?? 0;
    if (nowMs - lastRegister < _registerIntervalMs) {
      return true;
    }

    final response = await _registerResponse(
      preferredBaseUrl: baseUrl,
      deviceId: settings.deviceId,
      clientInstanceId: settings.clientInstanceId,
      deviceToken: settings.deviceToken,
      displayName: settings.displayName,
    );
    final ok =
        response.response.statusCode >= 200 &&
        response.response.statusCode < 300;
    if (!ok) {
      final serverError = _extractError(response.response.body);
      if (_isInvalidBindingError(serverError)) {
        await SettingsStore.instance.clearDeviceId();
      }
    }
    if (ok) {
      await LocalDb.instance.setMetaInt(_lastRegisterMetaKey, nowMs);
    }
    return ok;
  }

  Future<String> unlinkDevice() async {
    final l10n = await _l10n();
    late final AppSettings settings;
    try {
      settings = await SettingsStore.instance.load();
    } catch (_) {
      return l10n('missingSettings');
    }
    if (settings.deviceId.isEmpty) {
      return l10n('noDeviceLinked');
    }
    final baseUrl = settings.backendBaseUrl;
    final network = await hasNetwork();
    if (!network) {
      return l10n('noNetworkUnlinkSkipped');
    }
    final response = (await _postJsonWithFallback(
      preferredBaseUrl: baseUrl,
      path: '/api/v1/devices/unlink',
      payload: {
        'device_id': settings.deviceId,
        'client_instance_id': settings.clientInstanceId,
        'device_token': settings.deviceToken,
      },
      timeout: const Duration(seconds: 15),
    )).response;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return l10n('unlinkFailedHttp', {'code': '${response.statusCode}'});
    }
    return l10n('deviceUnlinked');
  }

  Future<_PostResult> _registerResponse({
    required String preferredBaseUrl,
    required String deviceId,
    required String clientInstanceId,
    required String deviceToken,
    required String displayName,
  }) {
    final payload = {
      'device_id': deviceId,
      'client_instance_id': clientInstanceId,
      'device_token': deviceToken,
      'display_name': displayName,
    };
    return _postJsonWithFallback(
      preferredBaseUrl: preferredBaseUrl,
      path: '/api/v1/devices/register',
      payload: payload,
      timeout: const Duration(seconds: 15),
    );
  }

  Future<String> _getLastRegisterError({
    required String preferredBaseUrl,
    required String deviceId,
    required String clientInstanceId,
    required String deviceToken,
    required String displayName,
  }) async {
    try {
      final response = await _registerResponse(
        preferredBaseUrl: preferredBaseUrl,
        deviceId: deviceId,
        clientInstanceId: clientInstanceId,
        deviceToken: deviceToken,
        displayName: displayName,
      );
      return _extractError(response.response.body);
    } catch (_) {
      return '';
    }
  }

  Future<void> _cleanupSyncedIfDue() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastCleanup =
        await LocalDb.instance.getMetaInt(_syncedCleanupMetaKey) ?? 0;
    if (nowMs - lastCleanup < 6 * 60 * 60 * 1000) {
      return;
    }
    await LocalDb.instance.deleteOlderThan(nowMs - _syncedRetentionMs);
    await LocalDb.instance.deleteSyncedOlderThan(nowMs - _syncedRetentionMs);
    await LocalDb.instance.setMetaInt(_syncedCleanupMetaKey, nowMs);
  }

  String _extractError(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return (decoded['error'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  bool _isInvalidBindingError(String message) {
    return message.contains('Unknown or inactive device ID') ||
        message.contains('Device ID already linked') ||
        message.contains('not linked to this physical device') ||
        message.contains('blocked for this device ID');
  }

  Iterable<String> _candidateBaseUrls(String preferredBaseUrl) sync* {
    final normalized = preferredBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (normalized.isNotEmpty) {
      yield normalized;
    }
  }

  bool _shouldTryNextBaseUrl(http.Response response) {
    if (response.statusCode == 404 || response.statusCode >= 500) {
      return true;
    }
    final contentType = response.headers['content-type'] ?? '';
    return contentType.contains('text/html');
  }

  Future<_PostResult> _postJsonWithFallback({
    required String preferredBaseUrl,
    required String path,
    required Object payload,
    required Duration timeout,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    http.Response? lastResponse;
    String? lastBaseUrl;

    for (final baseUrl in _candidateBaseUrls(preferredBaseUrl)) {
      final endpoint = Uri.parse('$baseUrl$path');
      try {
        final response = await _client
            .post(
              endpoint,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(timeout);
        if (_shouldTryNextBaseUrl(response)) {
          lastResponse = response;
          lastBaseUrl = baseUrl;
          continue;
        }
        return _PostResult(response: response, baseUrl: baseUrl);
      } on TimeoutException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      } on http.ClientException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastResponse != null && lastBaseUrl != null) {
      return _PostResult(response: lastResponse, baseUrl: lastBaseUrl);
    }
    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    throw StateError('No backend URL candidates available');
  }
}
