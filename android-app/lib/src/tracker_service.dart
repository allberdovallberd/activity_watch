import 'package:flutter/services.dart';

import 'local_db.dart';

class TrackerService {
  static const MethodChannel _nativeChannel = MethodChannel(
    'usage_collector/native',
  );
  static const _lastCollectionMetaKey = 'last_collection_ms';
  static const _lastAppScanMetaKey = 'last_app_scan_ms';
  static const _lastInventoryFingerprintMetaKey = 'last_inventory_fingerprint';
  static const _appInventoryChangedMetaKey = 'app_inventory_changed_ms';
  static const _appScanVersionMetaKey = 'app_scan_version';
  static const _appScanVersion = 5;
  static const _maxHistoryDays = 62;
  static const _appScanInterval = Duration(minutes: 15);
  static const _backfillCursorMetaKey = 'backfill_cursor_ms';
  static const _lastBackfillMetaKey = 'last_backfill_ms';
  static const _backfillInterval = Duration(minutes: 2);
  static const _maxFastCatchupDays = 2;
  static const _backfillDaysPerRun = 5;
  // Data usage collection is disabled for now; keep constants for future use.
  static const _lastDataUsageTotalKey = 'last_data_usage_total_bytes';
  static const _lastDataUsageCollectKey = 'last_data_usage_collect_ms';
  static const _lastAppDataUsageCollectKey = 'last_app_data_usage_collect_ms';
  static const _appDataUsageInterval = Duration(minutes: 5);

  String? _selfPackage;

  Future<bool> isUsagePermissionGranted() {
    return _nativeChannel
        .invokeMethod<bool>('hasUsageAccess')
        .then((v) => v ?? false)
        .catchError((_) async => false);
  }

  Future<void> requestUsagePermission() async {
    try {
      await _nativeChannel.invokeMethod('openUsageAccessSettings');
    } catch (_) {
      // ignore
    }
  }

  Future<int> collectInstalledAppsIfDue() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastScan = await LocalDb.instance.getMetaInt(_lastAppScanMetaKey) ?? 0;
    final currentScanVersion =
        await LocalDb.instance.getMetaInt(_appScanVersionMetaKey) ?? 0;
    final appCount = await LocalDb.instance.countInstalledApps();
    if (appCount > 0 &&
        currentScanVersion == _appScanVersion &&
        nowMs - lastScan < _appScanInterval.inMilliseconds) {
      return 0;
    }

    final rows = await _collectInstalledAppsNative();
    if (rows.isEmpty) {
      return 0;
    }
    rows.removeWhere(
      (row) => row.packageName.trim().isEmpty || row.appName.trim().isEmpty,
    );
    rows.sort((a, b) => a.packageName.compareTo(b.packageName));
    final newFingerprint = _inventoryFingerprint(rows);
    final oldFingerprint =
        await LocalDb.instance.getMeta(_lastInventoryFingerprintMetaKey);
    final changed = newFingerprint != oldFingerprint;
    if (!changed &&
        appCount > 0 &&
        nowMs - lastScan < _appScanInterval.inMilliseconds) {
      return 0;
    }

    await LocalDb.instance.replaceInstalledApps(rows);
    if (changed) {
      await LocalDb.instance.setMetaInt(_appInventoryChangedMetaKey, nowMs);
      await LocalDb.instance.setMeta(_lastInventoryFingerprintMetaKey, newFingerprint);
    }
    await LocalDb.instance.setMetaInt(_lastAppScanMetaKey, nowMs);
    await LocalDb.instance.setMetaInt(_appScanVersionMetaKey, _appScanVersion);
    return rows.length;
  }

  Future<int> collectUsageSinceLastRun() async {
    final usageGranted = await isUsagePermissionGranted();
    if (!usageGranted) {
      return 0;
    }

    final nowUtc = DateTime.now().toUtc();
    final nowTk = nowUtc.add(const Duration(hours: 5));
    final lastMsRaw = await LocalDb.instance.getMeta(_lastCollectionMetaKey);
    var lastMs = lastMsRaw == null ? null : int.tryParse(lastMsRaw);
    final maxLookbackUtc = nowUtc.subtract(const Duration(days: _maxHistoryDays));
    final maxLookbackTk = maxLookbackUtc.add(const Duration(hours: 5));
    final minTkDate = DateTime.utc(
      maxLookbackTk.year,
      maxLookbackTk.month,
      maxLookbackTk.day,
    );
    final todayTkStart = DateTime.utc(
      nowTk.year,
      nowTk.month,
      nowTk.day,
    );
    final todayStartUtc = todayTkStart.subtract(const Duration(hours: 5));
    final minLookbackUtc = minTkDate.subtract(const Duration(hours: 5));
    if (lastMs == null) {
      await LocalDb.instance.setMetaInt(
        _backfillCursorMetaKey,
        minLookbackUtc.millisecondsSinceEpoch,
      );
      await LocalDb.instance.setMetaInt(_lastBackfillMetaKey, 0);
      lastMs = todayStartUtc.millisecondsSinceEpoch;
      await LocalDb.instance.setMeta(
        _lastCollectionMetaKey,
        lastMs.toString(),
      );
    }

    final selfPackage = await _resolveSelfPackage();
    var collectedRows = 0;
    DateTime lastDayTk = DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true)
        .add(const Duration(hours: 5));
    var lastDayStartTk = DateTime.utc(
      lastDayTk.year,
      lastDayTk.month,
      lastDayTk.day,
    );
    var lastDayStartUtc = lastDayStartTk.subtract(const Duration(hours: 5));
    if (lastDayStartUtc.isBefore(minLookbackUtc)) {
      lastDayStartUtc = minLookbackUtc;
    }
    final daysBehind = todayStartUtc
        .difference(lastDayStartUtc)
        .inDays
        .clamp(0, 9999)
        .toInt();
    var catchupStartUtc = lastDayStartUtc;
    if (daysBehind >= _maxFastCatchupDays) {
      catchupStartUtc = todayStartUtc.subtract(
        Duration(days: _maxFastCatchupDays - 1),
      );
      if (catchupStartUtc.isBefore(minLookbackUtc)) {
        catchupStartUtc = minLookbackUtc;
      }
    }

    DateTime? lastProcessedEndUtc;
    var dayStartUtc = catchupStartUtc;
    while (!dayStartUtc.isAfter(todayStartUtc)) {
      final dayEndUtc = dayStartUtc.add(const Duration(days: 1));
      final queryEndUtc = dayStartUtc == todayStartUtc
          ? nowUtc
          : (dayEndUtc.isAfter(nowUtc) ? nowUtc : dayEndUtc);
      final intervalMs =
          queryEndUtc.millisecondsSinceEpoch - dayStartUtc.millisecondsSinceEpoch;
      final rows = <UsageRow>[];
      final appsUsage = await _getAppsUsageForInterval(
        dayStartUtc.millisecondsSinceEpoch,
        queryEndUtc.millisecondsSinceEpoch,
      );
      final isCurrentDay =
          nowUtc.isAfter(dayStartUtc) && nowUtc.isBefore(dayEndUtc);
      if (appsUsage.isEmpty && !isCurrentDay) {
        dayStartUtc = dayEndUtc;
        continue;
      }
      for (final entry in appsUsage) {
        final packageName = entry.packageName;
        if (packageName.isEmpty) {
          continue;
        }
        if (selfPackage != null && packageName == selfPackage) {
          continue;
        }
        final screenMs = entry.screenTimeMs;
        if (screenMs > 0) {
          final foregroundMs = screenMs > intervalMs ? intervalMs : screenMs;
          rows.add(
            UsageRow(
              packageName: packageName,
              startMs: dayStartUtc.millisecondsSinceEpoch,
              endMs: queryEndUtc.millisecondsSinceEpoch,
              foregroundMs: foregroundMs,
            ),
          );
        }
      }
      await LocalDb.instance.replaceUsageRowsForDay(
        dayStartUtc.millisecondsSinceEpoch,
        rows,
      );
      collectedRows += rows.length;
      lastProcessedEndUtc = queryEndUtc;
      dayStartUtc = dayEndUtc;
    }

    await LocalDb.instance.setMeta(
      _lastCollectionMetaKey,
      (lastProcessedEndUtc ?? nowUtc).millisecondsSinceEpoch.toString(),
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastBackfillMs =
        await LocalDb.instance.getMetaInt(_lastBackfillMetaKey) ?? 0;
    if (nowMs - lastBackfillMs >= _backfillInterval.inMilliseconds) {
      var cursorMs =
          await LocalDb.instance.getMetaInt(_backfillCursorMetaKey) ??
              minLookbackUtc.millisecondsSinceEpoch;
      var daysProcessed = 0;
      while (cursorMs < todayStartUtc.millisecondsSinceEpoch &&
          daysProcessed < _backfillDaysPerRun) {
        var backfillStartUtc =
            DateTime.fromMillisecondsSinceEpoch(cursorMs, isUtc: true);
        if (backfillStartUtc.isBefore(minLookbackUtc)) {
          backfillStartUtc = minLookbackUtc;
        }
        final backfillEndUtc = backfillStartUtc.add(const Duration(days: 1));
        final rows = <UsageRow>[];
        final appsUsage = await _getAppsUsageForInterval(
          backfillStartUtc.millisecondsSinceEpoch,
          backfillEndUtc.millisecondsSinceEpoch,
        );
        for (final entry in appsUsage) {
          final packageName = entry.packageName;
          if (packageName.isEmpty) {
            continue;
          }
          if (selfPackage != null && packageName == selfPackage) {
            continue;
          }
          final screenMs = entry.screenTimeMs;
          if (screenMs > 0) {
            final intervalMs = backfillEndUtc.millisecondsSinceEpoch -
                backfillStartUtc.millisecondsSinceEpoch;
            final foregroundMs = screenMs > intervalMs ? intervalMs : screenMs;
            rows.add(
              UsageRow(
                packageName: packageName,
                startMs: backfillStartUtc.millisecondsSinceEpoch,
                endMs: backfillEndUtc.millisecondsSinceEpoch,
                foregroundMs: foregroundMs,
              ),
            );
          }
        }
        await LocalDb.instance.replaceUsageRowsForDay(
          backfillStartUtc.millisecondsSinceEpoch,
          rows,
        );
        collectedRows += rows.length;
        cursorMs = backfillEndUtc.millisecondsSinceEpoch;
        daysProcessed += 1;
      }
      await LocalDb.instance.setMetaInt(_backfillCursorMetaKey, cursorMs);
      await LocalDb.instance.setMetaInt(_lastBackfillMetaKey, nowMs);
    }

    return collectedRows;
  }

  Future<int> collectDataUsageSinceLastRun() async {
    final totalBytes = await _getTotalDeviceBytes();
    if (totalBytes <= 0) {
      return 0;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastTotalRaw = await LocalDb.instance.getMeta(_lastDataUsageTotalKey);
    final lastCollectRaw =
        await LocalDb.instance.getMeta(_lastDataUsageCollectKey);
    final lastTotal = lastTotalRaw == null ? null : int.tryParse(lastTotalRaw);
    final lastCollectMs =
        lastCollectRaw == null ? null : int.tryParse(lastCollectRaw);

    if (lastTotal == null || lastCollectMs == null) {
      await LocalDb.instance.setMeta(_lastDataUsageTotalKey, totalBytes.toString());
      await LocalDb.instance.setMeta(
        _lastDataUsageCollectKey,
        nowMs.toString(),
      );
      return 0;
    }

    var delta = totalBytes - lastTotal;
    if (delta < 0) {
      delta = 0;
    }

    final rows = <DataUsageRow>[];
    if (delta > 0 && lastCollectMs < nowMs) {
      rows.add(
        DataUsageRow(
          startMs: lastCollectMs,
          endMs: nowMs,
          totalBytes: delta,
        ),
      );
      await LocalDb.instance.insertDataUsageRows(rows);
    }

    await LocalDb.instance.setMeta(_lastDataUsageTotalKey, totalBytes.toString());
    await LocalDb.instance.setMeta(
      _lastDataUsageCollectKey,
      nowMs.toString(),
    );
    return rows.length;
  }

  Future<int> collectAppDataUsageSinceLastRun() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastCollectMs =
        await LocalDb.instance.getMetaInt(_lastAppDataUsageCollectKey) ?? 0;
    if (lastCollectMs != 0 &&
        nowMs - lastCollectMs < _appDataUsageInterval.inMilliseconds) {
      return 0;
    }

    final totals = await _getAppTrafficTotals();
    if (totals.isEmpty) {
      return 0;
    }

    if (lastCollectMs == 0) {
      await LocalDb.instance.upsertAppDataUsageTotals(totals, nowMs);
      await LocalDb.instance.setMetaInt(_lastAppDataUsageCollectKey, nowMs);
      return 0;
    }

    final previousTotals = await LocalDb.instance.getAppDataUsageTotals();
    final rows = <AppDataUsageRow>[];
    totals.forEach((packageName, totalBytes) {
      final previous = previousTotals[packageName];
      if (previous == null) {
        return;
      }
      var delta = totalBytes - previous;
      if (delta < 0) {
        delta = 0;
      }
      if (delta <= 0) {
        return;
      }
      rows.add(
        AppDataUsageRow(
          packageName: packageName,
          startMs: lastCollectMs,
          endMs: nowMs,
          totalBytes: delta,
        ),
      );
    });

    await LocalDb.instance.insertAppDataUsageRows(rows);
    await LocalDb.instance.upsertAppDataUsageTotals(totals, nowMs);
    await LocalDb.instance.setMetaInt(_lastAppDataUsageCollectKey, nowMs);
    return rows.length;
  }

  int _parseMillis(dynamic raw) {
    if (raw == null) {
      return 0;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      return int.tryParse(raw) ?? 0;
    }
    return 0;
  }

  String _inventoryFingerprint(List<InstalledAppRow> rows) {
    var hash = 2166136261;
    for (final row in rows) {
      final iconSize = row.iconBase64?.length ?? 0;
      final token = '${row.packageName}|${row.appName}|$iconSize;';
      for (final unit in token.codeUnits) {
        hash ^= unit;
        hash = (hash * 16777619) & 0xffffffff;
      }
    }
    return hash.toRadixString(16);
  }

  Future<int> _getTotalDeviceBytes() async {
    try {
      final result = await _nativeChannel.invokeMethod<int>('getTotalBytes');
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, int>> _getAppTrafficTotals() async {
    try {
      final raw = await _nativeChannel.invokeMethod<List<dynamic>>(
        'getAppTrafficTotals',
      );
      if (raw == null) {
        return {};
      }
      final totals = <String, int>{};
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        final packageName = (item['package_name'] ?? '').toString().trim();
        if (packageName.isEmpty) {
          continue;
        }
        final totalRaw = item['total_bytes'];
        final total = _parseMillis(totalRaw);
        if (total >= 0) {
          totals[packageName] = total;
        }
      }
      return totals;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, int>> _getUsageEventTotals(int startMs, int endMs) async {
    try {
      final raw = await _nativeChannel.invokeMethod<List<dynamic>>(
        'getUsageEventTotals',
        {'start_ms': startMs, 'end_ms': endMs},
      );
      if (raw == null) {
        return {};
      }
      final totals = <String, int>{};
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        final packageName = (item['package_name'] ?? '').toString().trim();
        if (packageName.isEmpty) {
          continue;
        }
        final totalRaw = item['total_ms'];
        final total = _parseMillis(totalRaw);
        if (total > 0) {
          totals[packageName] = total;
        }
      }
      return totals;
    } catch (_) {
      return {};
    }
  }

  Future<List<AppsUsageEntry>> _getAppsUsageForInterval(
    int startMs,
    int endMs,
  ) async {
    try {
      final raw = await _nativeChannel.invokeMethod<List<dynamic>>(
        'getAppsUsageForInterval',
        {'start_ms': startMs, 'end_ms': endMs},
      );
      if (raw != null) {
        final entries = <AppsUsageEntry>[];
        for (final item in raw) {
          if (item is! Map) {
            continue;
          }
          final packageName = (item['package_name'] ?? '').toString().trim();
          if (packageName.isEmpty) {
            continue;
          }
          final screenMs = _parseMillis(item['screen_time_ms']);
          final mobileBytes = _parseMillis(item['mobile_bytes']);
          final wifiBytes = _parseMillis(item['wifi_bytes']);
          entries.add(
            AppsUsageEntry(
              packageName: packageName,
              screenTimeMs: screenMs,
              mobileBytes: mobileBytes,
              wifiBytes: wifiBytes,
            ),
          );
        }
        if (entries.isNotEmpty) {
          return entries;
        }
      }
    } catch (_) {
      // ignore
    }
    final fallback = await _getUsageEventTotals(startMs, endMs);
    return fallback.entries
        .map(
          (entry) => AppsUsageEntry(
            packageName: entry.key,
            screenTimeMs: entry.value,
            mobileBytes: 0,
            wifiBytes: 0,
          ),
        )
        .toList();
  }

  Future<List<InstalledAppRow>> _collectInstalledAppsNative() async {
    try {
      final raw = await _nativeChannel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );
      if (raw == null) {
        return <InstalledAppRow>[];
      }
      final rows = <InstalledAppRow>[];
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        final packageName = (item['package_name'] ?? '').toString().trim();
        if (packageName.isEmpty) {
          continue;
        }
        final appNameRaw = (item['app_name'] ?? '').toString().trim();
        final iconRaw = item['icon_base64'];
        final isSystemRaw = item['is_system'];
        final isTrackingRaw = item['is_tracking'];
        rows.add(
          InstalledAppRow(
            packageName: packageName,
            appName: appNameRaw.isEmpty ? packageName : appNameRaw,
            iconBase64: iconRaw?.toString(),
            isSystem: _parseBool(isSystemRaw),
            isTracking: _parseBool(isTrackingRaw),
          ),
        );
      }
      return rows;
    } catch (_) {
      return <InstalledAppRow>[];
    }
  }

  bool _parseBool(dynamic raw) {
    if (raw == null) {
      return false;
    }
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    if (raw is String) {
      final value = raw.trim().toLowerCase();
      return value == '1' || value == 'true' || value == 'yes' || value == 'y';
    }
    return false;
  }

  Future<String?> _resolveSelfPackage() async {
    if (_selfPackage != null) {
      return _selfPackage;
    }
    try {
      final result = await _nativeChannel.invokeMethod<String>('getSelfPackage');
      final trimmed = result?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        _selfPackage = trimmed;
      }
    } catch (_) {
      // ignore
    }
    return _selfPackage;
  }
}

class AppsUsageEntry {
  AppsUsageEntry({
    required this.packageName,
    required this.screenTimeMs,
    required this.mobileBytes,
    required this.wifiBytes,
  });

  final String packageName;
  final int screenTimeMs;
  final int mobileBytes;
  final int wifiBytes;
}
