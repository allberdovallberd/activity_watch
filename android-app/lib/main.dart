import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'src/app_locale_controller.dart';
import 'src/auto_runtime.dart';
import 'src/background_tasks.dart';
import 'src/local_db.dart';
import 'src/settings_store.dart';

export 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(LocalDb.instance.init());
  final localeController = AppLocaleController(
    settingsStore: SettingsStore.instance,
  );
  await localeController.load();
  runApp(UsageCollectorApp(localeController: localeController));
  unawaited(_initBackgroundTasks());
}

Future<void> _initBackgroundTasks() async {
  try {
    await Future<void>.delayed(const Duration(seconds: 5));
    await Workmanager().initialize(callbackDispatcher);
    await scheduleBackgroundTasks();
  } catch (_) {
    // Foreground service remains the primary always-on runtime.
  }
}

@pragma('vm:entry-point')
Future<void> backgroundServiceMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await LocalDb.instance.init();
  final runtime = AutoRuntime(onStatus: (_) {});
  const channel = MethodChannel('usage_collector/background_service');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'tick') {
      await runtime.triggerNow(trigger: 'native-tick');
      return true;
    }
    return false;
  });
  await runtime.start();
  await Future<void>.delayed(const Duration(days: 36500));
}
