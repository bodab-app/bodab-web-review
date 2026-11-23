import 'dart:convert';

/// Only committed, JSON-compatible fields belong here. Give each independent
/// entity its own stable key so simultaneous changes in different tabs merge.
abstract interface class ReviewSavedModel {
  String get storageKey;
  Map<String, Object?> exportSavedState();
  void restoreSavedState(Map<String, Object?> data);
}

enum ReviewStoreChange { updated, cleared }

class ReviewSnapshot {
  const ReviewSnapshot(this.generation, this.entries)
      : exampleDismissed = false;
  const ReviewSnapshot.empty({this.exampleDismissed = false})
      : generation = null,
        entries = const {};
  final String? generation;
  final bool exampleDismissed;
  final Map<String, Object?> entries;

  String encode() =>
      jsonEncode({'version': 1, 'generation': generation, 'entries': entries});
  static ReviewSnapshot decode(String data) {
    final value = jsonDecode(data);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['generation'] is! String ||
        (value['generation'] as String).isEmpty ||
        value['entries'] is! Map<String, dynamic>) {
      throw const FormatException();
    }
    return ReviewSnapshot(
        value['generation'] as String, Map.from(value['entries'] as Map));
  }
}

/// The store checks the generation and applies the whole patch atomically.
/// An old tab cannot re-create data after deletion, even if it missed a signal.
class ReviewWrite {
  const ReviewWrite(this.generation, this.put, this.remove,
      {this.enable = false, this.firstEntries = const {}});
  final String generation;
  final Map<String, Object?> put;
  final Set<String> remove;
  final bool enable;
  // An example baseline is applied only to a newly opted-in, untouched vault.
  final Map<String, Object?> firstEntries;
  ReviewSnapshot apply(ReviewSnapshot current) {
    if (!enable && current.generation != generation) return current;
    final merged = <String, Object?>{
      if (enable && current.generation == null && !current.exampleDismissed)
        ...firstEntries,
      ...current.entries,
    };
    for (final k in remove) {
      merged.remove(k);
    }
    merged.addAll(put);
    return ReviewSnapshot(current.generation ?? generation, merged);
  }
}

abstract interface class ReviewDeviceStore {
  Future<ReviewSnapshot> read();
  Future<ReviewSnapshot> write(ReviewWrite patch);
  Future<void> clear();
  Stream<ReviewStoreChange> get changes;
  void dispose();
}

/// Browser-only protection while an opted-in change has not been committed.
abstract interface class ReviewPendingGuard {
  void guardPending(bool pending);
}

String reviewVaultName({required bool exampleProfile}) =>
    exampleProfile ? 'bodab.everyday.example.v1' : 'bodab.everyday.personal.v1';
