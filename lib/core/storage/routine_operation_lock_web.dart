import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Origin-wide Web Lock. It serializes secure operation reservations across
/// browser tabs so two tabs cannot reserve different IDs for the same write.
Future<T> withRoutineOperationLock<T>(
  String name,
  Future<T> Function() action, {
  Duration pendingTimeout = const Duration(seconds: 5),
}) async {
  Object? result;
  Object? actionError;
  StackTrace? actionStackTrace;
  var actionCompleted = false;
  var lockAcquired = false;
  var lockTimedOut = false;
  final abortController = web.AbortController();
  late final Timer pendingTimer;
  final callback = ((web.Lock _) {
    lockAcquired = true;
    pendingTimer.cancel();

    Future<JSAny?> runAction() async {
      try {
        result = await action();
        actionCompleted = true;
      } catch (error, stackTrace) {
        actionError = error;
        actionStackTrace = stackTrace;
      }
      return null;
    }

    return runAction().toJS;
  }).toJS;
  pendingTimer = Timer(pendingTimeout, () {
    if (lockAcquired) return;
    lockTimedOut = true;
    abortController.abort();
  });
  try {
    final options = web.LockOptions(signal: abortController.signal);
    await web.window.navigator.locks.request(name, options, callback).toDart;
  } catch (error, stackTrace) {
    if (lockTimedOut) {
      throw TimeoutException(
          'Timed out waiting for the browser operation lock');
    }
    Error.throwWithStackTrace(error, stackTrace);
  } finally {
    pendingTimer.cancel();
  }
  if (actionError != null) {
    Error.throwWithStackTrace(actionError!, actionStackTrace!);
  }
  if (!actionCompleted) {
    throw StateError('Browser operation lock completed without an action');
  }
  return result as T;
}
