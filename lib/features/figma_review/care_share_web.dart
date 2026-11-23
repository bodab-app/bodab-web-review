import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('navigator.share')
external JSFunction? get _shareFunction;

bool get canUseShareSheet => _shareFunction != null;

Future<bool> openShareSheet(String subject, String text) async {
  if (!canUseShareSheet) return false;
  try {
    await web.window.navigator
        .share(web.ShareData(title: subject, text: text))
        .toDart;
    return true;
  } catch (_) {
    // AbortError also covers dismissing the native share sheet.
    return false;
  }
}
