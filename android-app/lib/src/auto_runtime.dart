import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'local_db.dart';
import 'sync_service.dart';
import 'tracker_service.dart';

class AutoRuntime {
  AutoRuntime({
    required this.onStatus,
  });

  final void Function(String message) onStatus;
  final TrackerService _tracker = TrackerService();
  final SyncService _sync = SyncService();
  Timer? _loopTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _busy = false;
  bool _running = false;
  int _lastCollectMs = 0;
  int _lastSyncMs = 0;
  int _lastCleanupMs = 0;

  static const _collectIntervalMs = 15 * 1000;
  static const _syncIntervalMs = 20 * 1000;
  static const _cleanupIntervalMs = 10 * 60 * 1000;

  Future<void> start() async {
    if (_running) {
      return;
    }
    _running = true;
    await LocalDb.instance.init();
    onStatus('Auto runtime started');
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          _runCycle(trigger: 'network-online');
        }
      });
    } catch (e) {
      onStatus('Connectivity listener unavailable: $e');
    }
    _loopTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _runCycle(trigger: 'periodic');
    });
    await _runCycle(trigger: 'startup');
  }

  Future<void> triggerNow({String trigger = 'manual'}) async {
    await _runCycle(trigger: trigger, force: true);
  }

  Future<void> stop() async {
    _running = false;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _loopTimer?.cancel();
    _loopTimer = null;
  }

  Future<void> _runCycle({required String trigger, bool force = false}) async {
    if (!_running || _busy) {
      return;
    }
    _busy = true;
    try {
      var apps = 0;
      var usageRows = 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final shouldCollect = force ||
          trigger == 'startup' ||
          trigger == 'network-online' ||
          nowMs - _lastCollectMs >= _collectIntervalMs;
      try {
        if (shouldCollect) {
          apps = await _tracker.collectInstalledAppsIfDue();
        }
      } catch (e) {
        onStatus('[$trigger] app collection failed: $e');
      }
      try {
        if (shouldCollect) {
          usageRows = await _tracker.collectUsageSinceLastRun();
        }
      } catch (e) {
        onStatus('[$trigger] usage collection failed: $e');
      }
      if (shouldCollect) {
        _lastCollectMs = nowMs;
      }
      // Data usage is collected together with screen time per day.
      try {
        if (nowMs - _lastCleanupMs >= _cleanupIntervalMs) {
          final retentionMs = 62 * 24 * 60 * 60 * 1000;
          await LocalDb.instance
              .deleteOlderThan(DateTime.now().millisecondsSinceEpoch - retentionMs);
          _lastCleanupMs = nowMs;
        }
      } catch (e) {
        onStatus('[$trigger] retention cleanup failed: $e');
      }
      final shouldSync = force ||
          usageRows > 0 ||
          trigger == 'network-online' ||
          (await _sync.hasNetwork() && (nowMs - _lastSyncMs >= _syncIntervalMs));
      final syncMsg = shouldSync ? await _sync.syncOnce() : 'Sync skipped';
      if (shouldSync) {
        _lastSyncMs = nowMs;
      }
      final unsynced = await LocalDb.instance.countUnsyncedUsage();
      onStatus(
        '[$trigger] apps=$apps usage=$usageRows'
        ' | $syncMsg | unsynced=$unsynced',
      );
    } catch (e) {
      onStatus('[$trigger] cycle failed: $e');
    } finally {
      _busy = false;
    }
  }
}
