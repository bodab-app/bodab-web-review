part of 'core.dart';

String _uniqueId() {
  final r = Random.secure();
  return List<int>.generate(16, (_) => r.nextInt(256))
      .map((i) => i.toRadixString(16).padLeft(2, '0'))
      .join();
}

Map<String, Object?> _asMap(Object? v) => Map<String, Object?>.from(v as Map);
bool _same(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length && a.indexed.every((p) => _same(p.$2, b[p.$1]));
  }
  return a == b;
}

Map<String, Object?> _encodeRecord(ReviewRecord r) => {
      'title': r.title,
      'detail': r.detail,
      'category': r.category,
      'createdAt': r.createdAt.toUtc().toIso8601String(),
      if (r is ReviewHealthCheck) ...{
        'type': 'checkin',
        'day': DateTime(r.day.year, r.day.month, r.day.day).toIso8601String(),
        'condition': r.condition,
        'memo': r.memo,
        if (r.answers.isNotEmpty)
          'answers': {for (final e in r.answers.entries) e.key.name: e.value},
      }
    };
ReviewRecord _decodeRecord(String id, Object? value) {
  final m = _asMap(value);
  final createdAt = DateTime.parse(m['createdAt'] as String).toLocal();
  if (m['type'] == 'checkin') {
    final savedAnswers = m['answers'];
    final answers = <CheckinField, String>{};
    if (savedAnswers is Map) {
      for (final field in CheckinField.values) {
        final value = savedAnswers[field.name];
        if (value is String && value.trim().isNotEmpty) answers[field] = value;
      }
    }
    final r = ReviewHealthCheck(DateTime.parse(m['day'] as String),
        m['condition'] as String, m['memo'] as String,
        answers: answers, createdAt: createdAt);
    if (r.id != id) throw const FormatException();
    return r;
  }
  if (m.containsKey('type')) throw const FormatException();
  return ReviewRecord(id, m['title'] as String, m['detail'] as String,
      m['category'] as String, createdAt);
}

class _PendingEntry {
  _PendingEntry(this.value, this.removed);
  final Object? value;
  final bool removed;
}

enum _Operation { read, flush, enable, clear }

abstract class _DeviceController extends ChangeNotifier {
  _DeviceController(this._store) : _ready = _store == null;
  final ReviewDeviceStore? _store;
  final Map<Type, Object> _models = {};
  final Map<String, Set<String>> _modelKeys = {};
  final List<ReviewRecord> _records = [];
  Map<String, Object?> _local = {};
  final Map<String, _PendingEntry> _dirty = {};
  Future<void> _queue = Future.value();
  StreamSubscription<ReviewStoreChange>? _subscription;
  Future<void>? _initialization;
  String? _generation;
  Map<String, Object?> _exampleBaseline = const {};
  bool _exampleDismissed = false;
  bool get isExampleAccount => _local['exampleAccount'] == true;

  void loadExampleAccount(
      Iterable<ReviewRecord> history, Iterable<ReviewSavedModel> features) {
    if (!_ready ||
        _error != null ||
        _generation != null ||
        _exampleDismissed ||
        _local.isNotEmpty ||
        _models.isNotEmpty ||
        _dirty.isNotEmpty) {
      return;
    }
    _exampleBaseline = {
      'exampleAccount': true,
      for (final record in history)
        'record/${record.id}': _encodeRecord(record),
      for (final feature in features)
        for (final entry in feature.exportSavedState().entries)
          'feature/${feature.storageKey}/${entry.key}': entry.value,
    };
    _install(ReviewSnapshot(null, _exampleBaseline));
  }

  bool _ready, _disposed = false;
  int _working = 0, _saves = 0, _clears = 0;
  String? _error;
  _Operation? _failed;
  static const _failure = '기기 저장소를 읽거나 변경하지 못했습니다. 이 창을 닫기 전에 다시 시도해 주세요.';
  List<ReviewRecord> get records => List.unmodifiable(_records);
  bool get storageReady => _ready;
  bool get deviceSavingEnabled => _generation != null;
  bool get storageBusy => _working > 0;
  bool get deviceWritePending => deviceSavingEnabled && _dirty.isNotEmpty;
  String? get storageError => _error;
  bool get isDisposed => _disposed;
  int get userSaveCount => _saves;
  int get clearCount => _clears;
  void _homeAfterClear();
  void _notify() {
    final guard = _store;
    if (guard is ReviewPendingGuard) {
      (guard as ReviewPendingGuard).guardPending(deviceWritePending);
    }
    if (!_disposed) notifyListeners();
  }

  Map<String, Object?> _section(Map<String, Object?> state, String key) {
    final prefix = 'feature/$key/';
    return {
      for (final e in state.entries)
        if (e.key.startsWith(prefix)) e.key.substring(prefix.length): e.value
    };
  }

  void _snapshotModel(ReviewSavedModel m, Map<String, Object?> state) {
    final prefix = 'feature/${m.storageKey}/';
    final values = m.exportSavedState();
    // Only delete keys understood by this version of the model. Unknown
    // extension fields from a newer compatible client stay in its snapshot.
    for (final k in _modelKeys[m.storageKey] ?? const <String>{}) {
      if (!values.containsKey(k)) state.remove('$prefix$k');
    }
    for (final e in values.entries) {
      final k = '$prefix${e.key}';
      if (!state.containsKey(k) || !_same(state[k], e.value)) {
        state[k] = jsonDecode(jsonEncode(e.value));
      }
    }
    _modelKeys[m.storageKey] = values.keys.toSet();
  }

  T model<T extends Object>(T Function() create) {
    return _models.putIfAbsent(T, () {
      final obj = create();
      if (obj is ReviewSavedModel) {
        final saved = _section(_local, obj.storageKey);
        if (saved.isNotEmpty) obj.restoreSavedState(saved);
        _snapshotModel(obj, _local);
      }
      return obj;
    }) as T;
  }

  void _changed({ReviewRecord? record, String? removedRecord}) {
    if (_disposed) return;
    final next = Map<String, Object?>.of(_local);
    if (record != null) next['record/${record.id}'] = _encodeRecord(record);
    if (removedRecord != null) next.remove('record/$removedRecord');
    for (final model in _models.values.whereType<ReviewSavedModel>()) {
      _snapshotModel(model, next);
    }
    bool affected = false, meaningful = false;
    for (final k in {..._local.keys, ...next.keys}) {
      if (_local.containsKey(k) == next.containsKey(k) &&
          _same(_local[k], next[k])) {
        continue;
      }
      _dirty[k] = _PendingEntry(next[k], !next.containsKey(k));
      affected = true;
      if (!k.contains('/pref:')) meaningful = true;
    }
    _local = next;
    if (meaningful) _saves++;
    _notify();
    if (affected && deviceSavingEnabled && _error == null) {
      unawaited(_run(_flush, operation: _Operation.flush));
    }
  }

  void _resetMemory() {
    _generation = null;
    _dirty.clear();
    _exampleBaseline = const {};
    _exampleDismissed = true;
    _local = {};
    _models.clear();
    _modelKeys.clear();
    _records.clear();
    _clears++;
    _homeAfterClear();
  }

  void _install(ReviewSnapshot snap) {
    if (_disposed) return;
    final next = Map<String, Object?>.of(snap.entries);
    for (final e in _dirty.entries) {
      if (e.value.removed) {
        next.remove(e.key);
      } else {
        next[e.key] = e.value.value;
      }
    }
    final list = [
      for (final e in next.entries)
        if (e.key.startsWith('record/'))
          _decodeRecord(e.key.substring(7), e.value)
    ]..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    for (final obj in _models.values.whereType<ReviewSavedModel>()) {
      final values = _section(next, obj.storageKey);
      if (!_same(values, _section(_local, obj.storageKey))) {
        obj.restoreSavedState(values);
      }
      _snapshotModel(obj, next);
    }
    _local = next;
    _generation = snap.generation;
    if (_generation != null) _exampleBaseline = const {};
    _records
      ..clear()
      ..addAll(list);
  }

  Future<bool> _run(Future<void> Function() action,
      {_Operation operation = _Operation.read}) {
    if (_disposed) return Future.value(false);
    final result = Completer<bool>();
    _working++;
    // Never dispatch synchronously here: parent controls and persistence are
    // allowed to schedule work while a model notifies its listeners.
    _queue = _queue.then((_) async {
      // Complete operations already accepted while the widget was mounted.
      _notify();
      try {
        await action();
        if (_failed == operation ||
            operation == _Operation.clear ||
            operation == _Operation.enable) {
          _failed = null;
          _error = null;
        }
        result.complete(true);
      } catch (_) {
        if (operation != _Operation.read || _failed == null) {
          _failed = operation;
        }
        _error = _failure;
        result.complete(false);
      } finally {
        _working--;
        _ready = true;
        _notify();
      }
    });
    return result.future;
  }

  Future<void> initializeDeviceStorage() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    if (_store == null) return;
    _subscription = _store!.changes.listen((change) {
      unawaited(_run(
          () => _refresh(clearSignal: change == ReviewStoreChange.cleared)));
    });
    await _run(_refresh);
  }

  Future<void> _refresh({bool clearSignal = false}) async {
    if (_store == null) return;
    final snap = await _store!.read();
    if (_disposed) return;
    if (snap.exampleDismissed) _exampleDismissed = true;
    if (_generation != null && snap.generation != _generation) {
      _resetMemory();
    } else if ((clearSignal ||
            (snap.exampleDismissed && _exampleBaseline.isNotEmpty)) &&
        snap.generation == null &&
        (_dirty.isNotEmpty || _records.isNotEmpty || _models.isNotEmpty)) {
      _resetMemory();
    }
    if (snap.generation != null) {
      // An opt-in in another tab does not implicitly retain this tab's
      // previously private session. This tab can choose to merge it explicitly.
      if (_generation != null || _dirty.isEmpty) _install(snap);
    }
  }

  Future<void> _flush({bool enable = false}) async {
    final store = _store;
    if (store == null) throw StateError('No device store');
    final generation = _generation ?? (enable ? _uniqueId() : null);
    if (generation == null || (_dirty.isEmpty && !enable)) return;
    final batch = Map<String, _PendingEntry>.of(_dirty);
    final patch = ReviewWrite(
        generation,
        {
          for (final e in batch.entries)
            if (!e.value.removed) e.key: e.value.value
        },
        {
          for (final e in batch.entries)
            if (e.value.removed) e.key
        },
        enable: enable,
        firstEntries: enable ? _exampleBaseline : const {});
    final snap = await store.write(patch);
    if (_disposed) return;
    if (!enable && snap.generation != generation) {
      _resetMemory();
      if (snap.generation != null) _install(snap);
      return;
    }
    for (final e in batch.entries) {
      if (identical(_dirty[e.key], e.value)) _dirty.remove(e.key);
    }
    _install(snap);
  }

  Future<bool> enableDeviceSaving() => _run(() async {
        await _flush(enable: true);
        if (_dirty.isNotEmpty) await _flush();
      }, operation: _Operation.enable);
  Future<bool> clearDeviceData() => _run(() async {
        await _store?.clear();
        if (!_disposed) _resetMemory();
      }, operation: _Operation.clear);
  Future<void> retryDeviceStorage() async {
    switch (_failed) {
      case _Operation.clear:
        await clearDeviceData();
      case _Operation.enable:
        await enableDeviceSaving();
      case _Operation.flush:
        await _run(_flush, operation: _Operation.flush);
      case _Operation.read || null:
        await _run(_refresh);
    }
  }

  Future<void> waitForDeviceWrites() => _queue;
  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    unawaited(_queue.whenComplete(() => _store?.dispose()));
    super.dispose();
  }
}
