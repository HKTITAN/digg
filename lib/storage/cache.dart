// On-disk cache built on Hive. Everything we fetch is kept for a week before
// eviction. The cache is the only persistence layer — the app starts cold
// against it on every launch, which is what makes "open offline and still
// see yesterday's stories" work.

import 'package:hive_flutter/hive_flutter.dart';

class DiggCache {
  static const _boxName = 'digg_cache_v1';

  /// One-week TTL on every entry. Stale-while-revalidate: the API layer
  /// always tries a fresh fetch first and falls back to whatever's in here.
  static const Duration ttl = Duration(days: 7);

  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    await _sweepExpired();
  }

  /// Read a cached entry. Returns null when expired unless [allowStale] is
  /// true (used by the API client as an offline fallback after a network
  /// failure).
  Future<Map<String, dynamic>?> read(String key, {bool allowStale = false}) async {
    final row = _box.get(key);
    if (row is! Map) return null;
    final exp = row['exp'] as int?;
    if (exp == null) return null;
    if (!allowStale && exp < DateTime.now().millisecondsSinceEpoch) return null;
    final val = row['val'];
    return val is Map ? Map<String, dynamic>.from(val) : null;
  }

  Future<void> write(String key, Map<String, dynamic> value, {Duration? customTtl}) async {
    final exp = DateTime.now().add(customTtl ?? ttl).millisecondsSinceEpoch;
    await _box.put(key, {'exp': exp, 'val': value});
  }

  Future<void> delete(String key) => _box.delete(key);

  Future<void> clear() => _box.clear();

  /// Total entries currently stored (including stale, before sweep).
  int get size => _box.length;

  /// Remove every expired entry. Cheap — we run it on launch and after each
  /// background poll.
  Future<int> _sweepExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final toDelete = <dynamic>[];
    for (final k in _box.keys) {
      final row = _box.get(k);
      if (row is! Map) continue;
      final exp = row['exp'] as int?;
      if (exp == null || exp < now) toDelete.add(k);
    }
    await _box.deleteAll(toDelete);
    return toDelete.length;
  }

  /// Public sweep — invoked after background polls.
  Future<int> sweep() => _sweepExpired();
}
