import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'pages/collector_home_page.dart';
import 'pages/permission_gate_page.dart';
import 'src/app_locale_controller.dart';
import 'src/tracker_service.dart';

class UsageCollectorApp extends StatefulWidget {
  const UsageCollectorApp({super.key, required this.localeController});

  final AppLocaleController localeController;

  @override
  State<UsageCollectorApp> createState() => _UsageCollectorAppState();
}

class _UsageCollectorAppState extends State<UsageCollectorApp>
    with WidgetsBindingObserver {
  static const MethodChannel _nativeChannel = MethodChannel(
    'usage_collector/native',
  );
  final TrackerService _tracker = TrackerService();
  Timer? _permissionTimer;
  bool _checkingPermissions = false;
  bool _permissionGranted = false;
  bool _usageGranted = false;
  bool _batteryGranted = false;
  bool _exactAlarmGranted = false;
  bool _deviceAdminGranted = false;
  bool _initialCheckDone = false;
  String _status = 'Booting...';
  int _lastPermissionCheckMs = 0;
  static const _permissionPollInterval = Duration(seconds: 30);
  static const _minCheckGapMs = 8 * 1000;
  Timer? _statusTimer;
  String? _pendingStatus;
  int _lastStatusUpdateMs = 0;
  static const _statusDebounceMs = 900;
  final int _bootMs = DateTime.now().millisecondsSinceEpoch;
  static const _firstPaintTimeoutMs = 2500;

  AppLocalizations get _l10n => widget.localeController.strings;

  @override
  void initState() {
    super.initState();
    _status = _l10n.booting;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionAndRoute(force: true);
    });
  }

  @override
  void dispose() {
    _permissionTimer?.cancel();
    _statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndRoute(force: true);
    }
  }

  Future<void> _checkPermissionAndRoute({bool force = false}) async {
    if (_checkingPermissions) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && nowMs - _lastPermissionCheckMs < _minCheckGapMs) {
      return;
    }
    _checkingPermissions = true;
    try {
      _lastPermissionCheckMs = nowMs;
      final results = await Future.wait<bool>([
        _safeCheck(_l10n.usageAccess, _tracker.isUsagePermissionGranted()),
        _safeCheck(
          _l10n.batteryOptimization,
          _isBatteryOptimizationIgnored(),
        ),
        _safeCheck(_l10n.exactAlarm, _canScheduleExactAlarms()),
        _safeCheck(_l10n.deviceAdmin, _isDeviceAdminActive()),
      ]);
      final usageGranted = results[0];
      final batteryGranted = results[1];
      final exactAlarmGranted = results[2];
      final deviceAdminGranted = results[3];
      final canCollect = usageGranted;
      final allGranted =
          usageGranted &&
          batteryGranted &&
          exactAlarmGranted &&
          deviceAdminGranted;
      if (!mounted) {
        return;
      }
      if (canCollect) {
        if (allGranted) {
          _updateStatus(_l10n.allPermissionsGranted);
        } else {
          _updateStatus(_l10n.usageAccessGrantedRemaining);
        }
      } else if (!allGranted) {
        final missing = <String>[];
        if (!usageGranted) {
          missing.add(_l10n.usageAccess);
        }
        if (!batteryGranted) {
          missing.add(_l10n.batteryOptimization);
        }
        if (!exactAlarmGranted) {
          missing.add(_l10n.exactAlarm);
        }
        if (!deviceAdminGranted) {
          missing.add(_l10n.deviceAdmin);
        }
        _updateStatus('${_l10n.grantRequiredPrefix}: ${missing.join(", ")}');
      } else {
        _updateStatus(_l10n.waitingUsageAccess);
      }

      if (mounted) {
        final changed =
            allGranted != _permissionGranted ||
            usageGranted != _usageGranted ||
            batteryGranted != _batteryGranted ||
            exactAlarmGranted != _exactAlarmGranted ||
            deviceAdminGranted != _deviceAdminGranted ||
            !_initialCheckDone;
        if (changed) {
          setState(() {
            _permissionGranted = allGranted;
            _usageGranted = usageGranted;
            _batteryGranted = batteryGranted;
            _exactAlarmGranted = exactAlarmGranted;
            _deviceAdminGranted = deviceAdminGranted;
            _initialCheckDone = true;
          });
        }
        _updatePermissionTimer(allGranted);
      }
    } finally {
      _checkingPermissions = false;
    }
  }

  void _updatePermissionTimer(bool allGranted) {
    if (allGranted) {
      _permissionTimer?.cancel();
      _permissionTimer = null;
      return;
    }
    if (_permissionTimer != null) {
      return;
    }
    _permissionTimer = Timer.periodic(_permissionPollInterval, (_) {
      _checkPermissionAndRoute();
    });
  }

  Future<bool> _safeCheck(String name, Future<bool> future) async {
    try {
      return await future.timeout(const Duration(seconds: 2));
    } catch (_) {
      _updateStatus(_l10n('checkTimedOut', {'name': name}));
      return false;
    }
  }

  void _updateStatus(String message) {
    if (!mounted) {
      return;
    }
    if (message == _status && _pendingStatus == null) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final since = nowMs - _lastStatusUpdateMs;
    if (since < _statusDebounceMs) {
      _pendingStatus = message;
      _statusTimer?.cancel();
      _statusTimer = Timer(
        Duration(milliseconds: _statusDebounceMs - since),
        () {
          if (!mounted) {
            return;
          }
          final pending = _pendingStatus;
          _pendingStatus = null;
          if (pending != null && pending != _status) {
            setState(() {
              _status = pending;
              _lastStatusUpdateMs = DateTime.now().millisecondsSinceEpoch;
            });
          }
        },
      );
      return;
    }
    setState(() {
      _status = message;
      _lastStatusUpdateMs = nowMs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final bootElapsed = nowMs - _bootMs;
    return ChangeNotifierProvider<AppLocaleController>.value(
      value: widget.localeController,
      child: Consumer<AppLocaleController>(
        builder: (context, controller, _) {
          final splashHome =
              !_initialCheckDone && bootElapsed < _firstPaintTimeoutMs;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: _l10n.appName,
            locale: controller.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            home: splashHome
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : (_permissionGranted
                      ? const CollectorHomePage()
                      : PermissionGatePage(
                          status: _status,
                          usageGranted: _usageGranted,
                          batteryGranted: _batteryGranted,
                          exactAlarmGranted: _exactAlarmGranted,
                          deviceAdminGranted: _deviceAdminGranted,
                          onOpenUsageAccess: () async {
                            await _openUsageAccessSettings();
                          },
                          onOpenBatteryOptimization: () async {
                            await _openBatteryOptimizationSettings();
                          },
                          onOpenExactAlarm: () async {
                            await _openExactAlarmSettings();
                          },
                          onOpenDeviceAdmin: () async {
                            await _requestDeviceAdmin();
                          },
                        )),
          );
        },
      ),
    );
  }

  Future<bool> _isBatteryOptimizationIgnored() async {
    try {
      final res = await _nativeChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canScheduleExactAlarms() async {
    try {
      final res = await _nativeChannel.invokeMethod<bool>('canScheduleExactAlarms');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openBatteryOptimizationSettings() async {
    try {
      await AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.example.usage_collector',
      ).launch();
    } catch (_) {
      try {
        await AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:com.example.usage_collector',
        ).launch();
      } catch (_) {}
    }
  }

  Future<void> _openExactAlarmSettings() async {
    try {
      await AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data: 'package:com.example.usage_collector',
      ).launch();
    } catch (_) {
      try {
        await AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:com.example.usage_collector',
        ).launch();
      } catch (_) {}
    }
  }

  Future<bool> _isDeviceAdminActive() async {
    try {
      final res = await _nativeChannel.invokeMethod<bool>('isDeviceAdminActive');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _requestDeviceAdmin() async {
    try {
      await AndroidIntent(action: 'android.settings.DEVICE_ADMIN_SETTINGS').launch();
    } catch (_) {
      try {
        await AndroidIntent(action: 'android.settings.SECURITY_SETTINGS').launch();
      } catch (_) {
        _updateStatus(_l10n.deviceAdminUnavailable);
      }
    }
  }

  Future<void> _openUsageAccessSettings() async {
    try {
      await AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS').launch();
    } catch (_) {
      await _tracker.requestUsagePermission();
    }
  }
}
