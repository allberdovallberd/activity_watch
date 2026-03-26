import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class InstalledAppRow {
  InstalledAppRow({
    required this.packageName,
    required this.appName,
    required this.iconBase64,
    required this.isSystem,
    required this.isTracking,
  });

  final String packageName;
  final String appName;
  final String? iconBase64;
  final bool isSystem;
  final bool isTracking;
}

class UsageRow {
  UsageRow({
    this.id,
    required this.packageName,
    required this.startMs,
    required this.endMs,
    required this.foregroundMs,
  });

  final int? id;
  final String packageName;
  final int startMs;
  final int endMs;
  final int foregroundMs;
}

class DataUsageRow {
  DataUsageRow({
    this.id,
    required this.startMs,
    required this.endMs,
    required this.totalBytes,
  });

  final int? id;
  final int startMs;
  final int endMs;
  final int totalBytes;
}

class AppDataUsageRow {
  AppDataUsageRow({
    this.id,
    required this.packageName,
    required this.startMs,
    required this.endMs,
    required this.totalBytes,
  });

  final int? id;
  final String packageName;
  final int startMs;
  final int endMs;
  final int totalBytes;
}

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static const _dbName = 'usage_collector.db';
  Database? _db;

  Future<void> init() async {
    if (_db != null) {
      return;
    }
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, _dbName);
    Future<Database> open() {
      return openDatabase(
        path,
        version: 7,
        onCreate: (db, version) async {
          await db.execute(
            '''
            CREATE TABLE installed_apps (
              package_name TEXT PRIMARY KEY,
              app_name TEXT NOT NULL,
              icon_base64 TEXT,
              is_system INTEGER NOT NULL DEFAULT 0,
              is_tracking INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL
            )
            ''',
          );
          await db.execute(
            '''
            CREATE TABLE usage_rows (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              package_name TEXT NOT NULL,
              start_ms INTEGER NOT NULL,
              end_ms INTEGER NOT NULL,
              foreground_ms INTEGER NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
            ''',
          );
          await db.execute(
            '''
            CREATE UNIQUE INDEX idx_usage_unique_start
            ON usage_rows(package_name, start_ms)
            ''',
          );
          await db.execute(
            '''
            CREATE TABLE data_usage_rows (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              start_ms INTEGER NOT NULL,
              end_ms INTEGER NOT NULL,
              total_bytes INTEGER NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
            ''',
          );
          await db.execute(
            '''
            CREATE UNIQUE INDEX idx_data_usage_unique
            ON data_usage_rows(start_ms, end_ms)
            ''',
          );
          await db.execute(
            '''
            CREATE TABLE app_data_usage_rows (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              package_name TEXT NOT NULL,
              start_ms INTEGER NOT NULL,
              end_ms INTEGER NOT NULL,
              total_bytes INTEGER NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
            ''',
          );
          await db.execute(
            '''
            CREATE UNIQUE INDEX idx_app_data_usage_unique_start
            ON app_data_usage_rows(package_name, start_ms)
            ''',
          );
          await db.execute(
            '''
            CREATE TABLE app_data_usage_totals (
              package_name TEXT PRIMARY KEY,
              total_bytes INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
            ''',
          );
          await db.execute(
            '''
            CREATE TABLE meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
            ''',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              '''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_usage_unique
              ON usage_rows(package_name, start_ms, end_ms)
              ''',
            );
          }
          if (oldVersion < 3) {
            await db.execute(
              '''
              CREATE TABLE IF NOT EXISTS data_usage_rows (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                total_bytes INTEGER NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL
              )
              ''',
            );
            await db.execute(
              '''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_data_usage_unique
              ON data_usage_rows(start_ms, end_ms)
              ''',
            );
          }
          if (oldVersion < 4) {
            await db.execute(
              '''
              ALTER TABLE installed_apps ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0
              ''',
            );
            await db.execute(
              '''
              ALTER TABLE installed_apps ADD COLUMN is_tracking INTEGER NOT NULL DEFAULT 0
              ''',
            );
            await db.execute('DELETE FROM usage_rows');
            await db.execute(
              '''
              DELETE FROM meta WHERE key = 'last_collection_ms'
              ''',
            );
            await db.execute('DROP INDEX IF EXISTS idx_usage_unique');
            await db.execute('DROP INDEX IF EXISTS idx_usage_unique_start');
            await db.execute(
              '''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_usage_unique_start
              ON usage_rows(package_name, start_ms)
              ''',
            );
          }
          if (oldVersion < 5) {
            await db.execute(
              '''
              CREATE TABLE IF NOT EXISTS app_data_usage_rows (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                package_name TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                total_bytes INTEGER NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL
              )
              ''',
            );
            await db.execute(
              '''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_app_data_usage_unique_start
              ON app_data_usage_rows(package_name, start_ms)
              ''',
            );
            await db.execute(
              '''
              CREATE TABLE IF NOT EXISTS app_data_usage_totals (
                package_name TEXT PRIMARY KEY,
                total_bytes INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
              ''',
            );
            await db.execute(
              '''
              DELETE FROM meta WHERE key = 'last_app_data_usage_collect_ms'
              ''',
            );
          }
          if (oldVersion < 6) {
            await db.execute('DELETE FROM data_usage_rows');
            await db.execute('DELETE FROM app_data_usage_rows');
            await db.execute('DELETE FROM app_data_usage_totals');
            await db.execute(
              '''
              DELETE FROM meta WHERE key IN (
                'last_data_usage_total_bytes',
                'last_data_usage_collect_ms',
                'last_app_data_usage_collect_ms'
              )
              ''',
            );
          }
          if (oldVersion < 7) {
            await db.execute('DELETE FROM data_usage_rows');
            await db.execute('DELETE FROM app_data_usage_rows');
            await db.execute('DELETE FROM app_data_usage_totals');
            await db.execute(
              '''
              DELETE FROM meta WHERE key IN (
                'last_data_usage_total_bytes',
                'last_data_usage_collect_ms',
                'last_app_data_usage_collect_ms'
              )
              ''',
            );
          }
        },
      );
    }

    try {
      _db = await open();
    } catch (_) {
      await deleteDatabase(path);
      _db = await open();
    }
  }

  Database get _safeDb {
    final db = _db;
    if (db == null) {
      throw StateError('LocalDb.init() must be called before use');
    }
    return db;
  }

  Future<void> upsertInstalledApps(List<InstalledAppRow> rows) async {
    if (rows.isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _safeDb.batch();
    for (final row in rows) {
      batch.insert(
        'installed_apps',
        {
          'package_name': row.packageName,
          'app_name': row.appName,
          'icon_base64': row.iconBase64,
          'is_system': row.isSystem ? 1 : 0,
          'is_tracking': row.isTracking ? 1 : 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceInstalledApps(List<InstalledAppRow> rows) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _safeDb.transaction((txn) async {
      await txn.delete('installed_apps');
      if (rows.isEmpty) {
        return;
      }
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(
          'installed_apps',
          {
            'package_name': row.packageName,
            'app_name': row.appName,
            'icon_base64': row.iconBase64,
            'is_system': row.isSystem ? 1 : 0,
            'is_tracking': row.isTracking ? 1 : 0,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertUsageRows(List<UsageRow> rows) async {
    if (rows.isEmpty) {
      return;
    }
    final batch = _safeDb.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      batch.insert('usage_rows', {
        'package_name': row.packageName,
        'start_ms': row.startMs,
        'end_ms': row.endMs,
        'foreground_ms': row.foregroundMs,
        'synced': 0,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceUsageRowsForDay(int dayStartMs, List<UsageRow> rows) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _safeDb.transaction((txn) async {
      await txn.delete('usage_rows', where: 'start_ms = ?', whereArgs: [dayStartMs]);
      if (rows.isEmpty) {
        return;
      }
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(
          'usage_rows',
          {
            'package_name': row.packageName,
            'start_ms': row.startMs,
            'end_ms': row.endMs,
            'foreground_ms': row.foregroundMs,
            'synced': 0,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertDataUsageRows(List<DataUsageRow> rows) async {
    if (rows.isEmpty) {
      return;
    }
    final batch = _safeDb.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      batch.insert(
        'data_usage_rows',
        {
          'start_ms': row.startMs,
          'end_ms': row.endMs,
          'total_bytes': row.totalBytes,
          'synced': 0,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceDataUsageRowsForDay(
    int dayStartMs,
    List<DataUsageRow> rows,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _safeDb.transaction((txn) async {
      await txn.delete('data_usage_rows', where: 'start_ms = ?', whereArgs: [dayStartMs]);
      if (rows.isEmpty) {
        return;
      }
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(
          'data_usage_rows',
          {
            'start_ms': row.startMs,
            'end_ms': row.endMs,
            'total_bytes': row.totalBytes,
            'synced': 0,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertAppDataUsageRows(List<AppDataUsageRow> rows) async {
    if (rows.isEmpty) {
      return;
    }
    final batch = _safeDb.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      batch.insert(
        'app_data_usage_rows',
        {
          'package_name': row.packageName,
          'start_ms': row.startMs,
          'end_ms': row.endMs,
          'total_bytes': row.totalBytes,
          'synced': 0,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceAppDataUsageRowsForDay(
    int dayStartMs,
    List<AppDataUsageRow> rows,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _safeDb.transaction((txn) async {
      await txn.delete(
        'app_data_usage_rows',
        where: 'start_ms = ?',
        whereArgs: [dayStartMs],
      );
      if (rows.isEmpty) {
        return;
      }
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(
          'app_data_usage_rows',
          {
            'package_name': row.packageName,
            'start_ms': row.startMs,
            'end_ms': row.endMs,
            'total_bytes': row.totalBytes,
            'synced': 0,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<InstalledAppRow>> getInstalledApps() async {
    final result = await _safeDb.query('installed_apps');
    return result
        .map(
          (row) => InstalledAppRow(
            packageName: row['package_name'] as String,
            appName: row['app_name'] as String,
            iconBase64: row['icon_base64'] as String?,
            isSystem: (row['is_system'] as int? ?? 0) != 0,
            isTracking: (row['is_tracking'] as int? ?? 0) != 0,
          ),
        )
        .toList();
  }

  Future<int> countInstalledApps() async {
    final result = await _safeDb.rawQuery(
      'SELECT COUNT(*) AS c FROM installed_apps',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<List<InstalledAppRow>> getInstalledAppsChangedSince(int sinceMs) async {
    final result = await _safeDb.query(
      'installed_apps',
      where: 'updated_at > ?',
      whereArgs: [sinceMs],
    );
    return result
        .map(
          (row) => InstalledAppRow(
            packageName: row['package_name'] as String,
            appName: row['app_name'] as String,
            iconBase64: row['icon_base64'] as String?,
            isSystem: (row['is_system'] as int? ?? 0) != 0,
            isTracking: (row['is_tracking'] as int? ?? 0) != 0,
          ),
        )
        .toList();
  }

  Future<List<UsageRow>> getUnsyncedUsage({int limit = 500}) async {
    final result = await _safeDb.query(
      'usage_rows',
      where: 'synced = 0',
      orderBy: 'id ASC',
      limit: limit,
    );
    return result
        .map(
          (row) => UsageRow(
            id: row['id'] as int,
            packageName: row['package_name'] as String,
            startMs: row['start_ms'] as int,
            endMs: row['end_ms'] as int,
            foregroundMs: row['foreground_ms'] as int,
          ),
        )
        .toList();
  }

  Future<List<DataUsageRow>> getUnsyncedDataUsage({int limit = 500}) async {
    final result = await _safeDb.query(
      'data_usage_rows',
      where: 'synced = 0',
      orderBy: 'id ASC',
      limit: limit,
    );
    return result
        .map(
          (row) => DataUsageRow(
            id: row['id'] as int,
            startMs: row['start_ms'] as int,
            endMs: row['end_ms'] as int,
            totalBytes: row['total_bytes'] as int,
          ),
        )
        .toList();
  }

  Future<List<AppDataUsageRow>> getUnsyncedAppDataUsage({int limit = 500}) async {
    final result = await _safeDb.query(
      'app_data_usage_rows',
      where: 'synced = 0',
      orderBy: 'id ASC',
      limit: limit,
    );
    return result
        .map(
          (row) => AppDataUsageRow(
            id: row['id'] as int,
            packageName: row['package_name'] as String,
            startMs: row['start_ms'] as int,
            endMs: row['end_ms'] as int,
            totalBytes: row['total_bytes'] as int,
          ),
        )
        .toList();
  }

  Future<int> countUnsyncedUsage() async {
    final result = await _safeDb.rawQuery(
      'SELECT COUNT(*) AS c FROM usage_rows WHERE synced = 0',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> countUnsyncedDataUsage() async {
    final result = await _safeDb.rawQuery(
      'SELECT COUNT(*) AS c FROM data_usage_rows WHERE synced = 0',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> countUnsyncedAppDataUsage() async {
    final result = await _safeDb.rawQuery(
      'SELECT COUNT(*) AS c FROM app_data_usage_rows WHERE synced = 0',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> markUsageSynced(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final placeholders = List.filled(ids.length, '?').join(',');
    await _safeDb.rawUpdate(
      'UPDATE usage_rows SET synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<void> markDataUsageSynced(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final placeholders = List.filled(ids.length, '?').join(',');
    await _safeDb.rawUpdate(
      'UPDATE data_usage_rows SET synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<void> markAppDataUsageSynced(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final placeholders = List.filled(ids.length, '?').join(',');
    await _safeDb.rawUpdate(
      'UPDATE app_data_usage_rows SET synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<void> deleteSyncedOlderThan(int timestampMs) async {
    await _safeDb.delete(
      'usage_rows',
      where: 'synced = 1 AND end_ms < ?',
      whereArgs: [timestampMs],
    );
    await _safeDb.delete(
      'data_usage_rows',
      where: 'synced = 1 AND end_ms < ?',
      whereArgs: [timestampMs],
    );
    await _safeDb.delete(
      'app_data_usage_rows',
      where: 'synced = 1 AND end_ms < ?',
      whereArgs: [timestampMs],
    );
  }

  Future<void> deleteOlderThan(int timestampMs) async {
    await _safeDb.delete(
      'usage_rows',
      where: 'end_ms < ?',
      whereArgs: [timestampMs],
    );
    await _safeDb.delete(
      'data_usage_rows',
      where: 'end_ms < ?',
      whereArgs: [timestampMs],
    );
    await _safeDb.delete(
      'app_data_usage_rows',
      where: 'end_ms < ?',
      whereArgs: [timestampMs],
    );
  }

  Future<Map<String, int>> getAppDataUsageTotals() async {
    final result = await _safeDb.query('app_data_usage_totals');
    final totals = <String, int>{};
    for (final row in result) {
      totals[row['package_name'] as String] = row['total_bytes'] as int;
    }
    return totals;
  }

  Future<void> upsertAppDataUsageTotals(
    Map<String, int> totals,
    int updatedAtMs,
  ) async {
    if (totals.isEmpty) {
      return;
    }
    final batch = _safeDb.batch();
    totals.forEach((packageName, totalBytes) {
      batch.insert(
        'app_data_usage_totals',
        {
          'package_name': packageName,
          'total_bytes': totalBytes,
          'updated_at': updatedAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }

  Future<String?> getMeta(String key) async {
    final result = await _safeDb.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) {
      return null;
    }
    return result.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) async {
    await _safeDb.insert(
      'meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> getMetaInt(String key) async {
    final raw = await getMeta(key);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setMetaInt(String key, int value) async {
    await setMeta(key, value.toString());
  }
}
