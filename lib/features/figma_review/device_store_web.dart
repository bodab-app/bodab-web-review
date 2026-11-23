// @dart=3.4

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../core/storage/routine_operation_lock.dart';
import 'device_store_api.dart';

ReviewDeviceStore createReviewDeviceStore({bool exampleProfile = false}) =>
    _WebReviewStore(reviewVaultName(exampleProfile: exampleProfile));

@JS()
extension type _EncryptedRow._(JSObject _) implements JSObject {
  external factory _EncryptedRow(
      {required web.CryptoKey key,
      required JSUint8Array iv,
      required JSArrayBuffer data});
  external web.CryptoKey get key;
  external JSUint8Array get iv;
  external JSArrayBuffer get data;
}

@JS()
extension type _Cipher._(JSObject _) implements JSObject {
  external factory _Cipher({required String name, required JSUint8Array iv});
}

/// An origin-private, structured-cloned nonextractable CryptoKey and its
/// ciphertext are committed together. Neither raw records nor raw key bytes
/// are written to localStorage, cookies, cache storage, or the network.
class _WebReviewStore implements ReviewDeviceStore, ReviewPendingGuard {
  final String _name;
  static const _table = 'vault';
  static const _record = 'personal';
  static const _dismissed = 'exampleDismissed';
  final _events = StreamController<ReviewStoreChange>.broadcast();
  web.BroadcastChannel? _channel;
  late final JSFunction _wake;
  _WebReviewStore(this._name) {
    _wake = ((web.Event _) {
      if (web.document.visibilityState == 'visible') {
        _events.add(ReviewStoreChange.updated);
      }
    }).toJS;
    web.document.addEventListener('visibilitychange', _wake);
    try {
      _channel = web.BroadcastChannel(_name);
      _channel!.onmessage = ((web.MessageEvent e) {
        _events.add(e.data.dartify() == 'clear'
            ? ReviewStoreChange.cleared
            : ReviewStoreChange.updated);
      }).toJS;
    } catch (_) {/* Visibility changes still refresh this tab. */}
  }
  late final JSFunction _beforeUnload = ((web.BeforeUnloadEvent event) {
    event.preventDefault();
    event.returnValue = '';
  }).toJS;
  bool _guarding = false;
  @override
  void guardPending(bool pending) {
    if (_guarding == pending) return;
    _guarding = pending;
    if (pending) {
      web.window.addEventListener('beforeunload', _beforeUnload);
    } else {
      web.window.removeEventListener('beforeunload', _beforeUnload);
    }
  }

  @override
  Stream<ReviewStoreChange> get changes => _events.stream;

  Future<web.IDBDatabase> _open() {
    final c = Completer<web.IDBDatabase>();
    final req = web.window.indexedDB.open(_name, 1);
    req.onupgradeneeded = ((web.Event _) {
      final db = req.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_table)) db.createObjectStore(_table);
    }).toJS;
    req.onsuccess = ((web.Event _) {
      final db = req.result as web.IDBDatabase;
      if (c.isCompleted) {
        db.close();
      } else {
        c.complete(db);
      }
    }).toJS;
    void fail() {
      if (!c.isCompleted) {
        c.completeError(StateError('Device storage unavailable'));
      }
    }

    req.onerror = ((web.Event _) => fail()).toJS;
    req.onblocked = ((web.Event _) => fail()).toJS;
    final timer = Timer(const Duration(seconds: 6), fail);
    return c.future.whenComplete(timer.cancel);
  }

  Future<T> _using<T>(Future<T> Function(web.IDBDatabase) fn) async {
    final db = await _open();
    try {
      return await fn(db);
    } finally {
      db.close();
    }
  }

  Future<(_EncryptedRow?, bool)> _readRow(web.IDBDatabase db) {
    final c = Completer<(_EncryptedRow?, bool)>();
    final tx = db.transaction(_table.toJS, 'readonly');
    final store = tx.objectStore(_table);
    final record = store.get(_record.toJS);
    final dismissed = store.get(_dismissed.toJS);
    tx.oncomplete = ((web.Event _) => c.complete((
          record.result as _EncryptedRow?,
          dismissed.result.dartify() == true
        ))).toJS;
    tx.onabort = ((web.Event _) =>
        c.completeError(StateError('Device read failed'))).toJS;
    return c.future;
  }

  Future<void> _replace(web.IDBDatabase db, _EncryptedRow? row) {
    final tx = db.transaction(_table.toJS, 'readwrite');
    final c = Completer<void>();
    tx.oncomplete = ((web.Event _) => c.complete()).toJS;
    tx.onabort = ((web.Event _) =>
        c.completeError(StateError('Device transaction failed'))).toJS;
    final store = tx.objectStore(_table);
    if (row == null) {
      store.delete(_record.toJS);
      store.put(true.toJS, _dismissed.toJS);
    } else {
      store.put(row, _record.toJS);
    }
    return c.future;
  }

  Future<ReviewSnapshot> _decode((_EncryptedRow?, bool) stored) async {
    final (row, dismissed) = stored;
    if (row == null) return ReviewSnapshot.empty(exampleDismissed: dismissed);
    final raw = await web.window.crypto.subtle
        .decrypt(_Cipher(name: 'AES-GCM', iv: row.iv), row.key, row.data)
        .toDart;
    return ReviewSnapshot.decode(
        utf8.decode((raw as JSArrayBuffer).toDart.asUint8List()));
  }

  @override
  Future<ReviewSnapshot> read() =>
      _using((db) async => _decode(await _readRow(db)));
  @override
  Future<ReviewSnapshot> write(ReviewWrite patch) => withRoutineOperationLock(
      _name,
      () => _using((db) async {
            final stored = await _readRow(db);
            final old = await _decode(stored);
            final next = patch.apply(old);
            if (identical(old, next)) return old;
            final crypto = web.window.crypto;
            final key = stored.$1?.key ??
                await crypto.subtle
                    .generateKey({'name': 'AES-GCM', 'length': 256}.jsify()!,
                        false, ['encrypt'.toJS, 'decrypt'.toJS].toJS)
                    .toDart as web.CryptoKey;
            final iv = Uint8List(12).toJS;
            crypto.getRandomValues(iv);
            final data = await crypto.subtle
                .encrypt(_Cipher(name: 'AES-GCM', iv: iv), key,
                    Uint8List.fromList(utf8.encode(next.encode())).toJS)
                .toDart as JSArrayBuffer;
            await _replace(db, _EncryptedRow(key: key, iv: iv, data: data));
            _notify('modified');
            return next;
          }));
  @override
  Future<void> clear() => withRoutineOperationLock(
      _name,
      () => _using((db) async {
            // A corrupt row can still be erased without first decrypting it.
            await _replace(db, null);
            _notify('clear');
          }));

  void _notify(String value) {
    try {
      _channel?.postMessage(value.toJS);
    } catch (_) {/* Already committed. */}
  }

  @override
  void dispose() {
    guardPending(false);
    web.document.removeEventListener('visibilitychange', _wake);
    _channel?.close();
    _events.close();
  }
}
