// On-disk cache built on Hive, with a memory-only fallback if the box
// can't be opened (rare, but it's happened on Android when the app data
// dir is in a weird state — and a failed cache must never bring down the
// app, hence the fallback).
//
// Entries live for a week before eviction; the API client treats expired
// entries as missing on fresh fetch but as a fallback when offline
// (stale-while-revalidate).

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DiggCache {
  static const _boxName = 'digg_cache_v1';
  static const Duration ttl = Duration(days: 7);

  Box? _box;
  final Map<String, _Row> _mem = <String, _Row>{};
  bool _diskAvailable = false;

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      _diskAvailable = true;
      await _sweepExpired();
    } catch (e, st) {
      // Fall back to in-memory so the app still works.
      debugPrint('DiggCache: disk init failed, running memory-only: $e\n$st');
      _diskAvailable = false;
    }
  }

  Future<Map<String, dynamic>?> read(String key, {bool allowStale = false}) async {
    final row = _readRow(key);
    if (row == null) return null;
    if (!allowStale && row.exp < DateTime.now().millisecondsSinceEpoch) return null;
    final val = row.val;
    return val is Map ? Map<String, dynamic>.from(val) : null;
  }

  Future<void> write(String key, Map<String, dynamic> value, {Duration? customTtl}) async {
    final row = _Row(
      exp: DateTime.now().add(customTtl ?? ttl).millisecondsSinceEpoch,
      val: value,
    );
    _mem[key] = row;
    if (_diskAvailable && _box != null) {
      try {
        await _box!.put(key, {'exp': row.exp, 'val': value});
      } catch (_) {/* keep memory copy */}
    }
  }

  Future<void> delete(String key) async {
    _mem.remove(key);
    if (_diskAvailable && _box != null) {
      try { await _box!.delete(key); } catch (_) {}
    }
  }

  Future<void> clear() async {
    _mem.clear();
    if (_diskAvailable && _box != null) {
      try { await _box!.clear(); } catch (_) {}
    }
  }

  int get size => _diskAvailable && _box != null ? _box!.length : _mem.length;

  Future<int> sweep() => _sweepExpired();

  // ---- internals ----

  _Row? _readRow(String key) {
    final mem = _mem[key];
    if (mem != null) return mem;
    if (!_diskAvailable || _box == null) return null;
    try {
      final raw = _box!.get(key);
      if (raw is! Map) return null;
      final exp = raw['exp'] as int?;
      if (exp == null) return null;
      final row = _Row(exp: exp, val: raw['val']);
      _mem[key] = row;
      return row;
    } catch (_) {
      return null;
    }
  }

  Future<int> _sweepExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var dropped = 0;
    _mem.removeWhere((_, row) {
      if (row.exp < now) { dropped++; return true; }
      return false;
    });
    if (_diskAvailable && _box != null) {
      try {
        final box = _box!;
        final toDelete = <dynamic>[];
        for (final k in box.keys) {
          final r = box.get(k);
          if (r is! Map) continue;
          final exp = r['exp'] as int?;
          if (exp == null || exp < now) toDelete.add(k);
        }
        await box.deleteAll(toDelete);
        dropped += toDelete.length;
      } catch (_) {}
    }
    return dropped;
  }
}

class _Row {
  final int exp;
  final dynamic val;
  _Row({required this.exp, required this.val});
}
