import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'local_db.dart';
import 'sync_service.dart';
import 'tracker_service.dart';

const String collectTaskName = 'usage_collect_task';
const String syncTaskName = 'usage_sync_task';
const String collectPulseTaskName = 'usage_collect_pulse';
const String syncPulseTaskName = 'usage_sync_pulse';

class TaskResult {
  const TaskResult(this.message);
  final String message;
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await LocalDb.instance.init();

    if (task == collectTaskName) {
      await runCollectionCycle();
      return true;
    }
    if (task == syncTaskName || task == syncPulseTaskName) {
      await runSyncCycle();
      return true;
    }
    if (task == collectPulseTaskName) {
      await runCollectionCycle();
      return true;
    }
    return true;
  });
}

Future<void> scheduleBackgroundTasks() async {
  await Workmanager().registerOneOffTask(
    'usage_collect_bootstrap',
    collectTaskName,
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );

  await Workmanager().registerOneOffTask(
    'usage_sync_bootstrap',
    syncTaskName,
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );

  await Workmanager().registerPeriodicTask(
    collectTaskName,
    collectTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  await Workmanager().registerPeriodicTask(
    syncTaskName,
    syncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // Foreground service handles high-frequency collection/sync.
}

Future<TaskResult> runCollectionCycle() async {
  try {
    final tracker = TrackerService();
    final appCount = await tracker.collectInstalledAppsIfDue();
    final usageCount = await tracker.collectUsageSinceLastRun();
    final retentionMs = 62 * 24 * 60 * 60 * 1000;
    await LocalDb.instance
        .deleteOlderThan(DateTime.now().millisecondsSinceEpoch - retentionMs);
    return TaskResult(
      'Collected $appCount apps, $usageCount usage rows',
    );
  } catch (e) {
    return TaskResult('Collect failed: $e');
  }
}

Future<TaskResult> runSyncCycle() async {
  try {
    final msg = await SyncService().syncOnce();
    return TaskResult(msg);
  } catch (e) {
    return TaskResult('Sync failed: $e');
  }
}
