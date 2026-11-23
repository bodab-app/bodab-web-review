import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// A user-selected document is handed only to the browser's native PDF viewer.
class LocalPdfPreview {
  static const supported = true;
  String? _url;
  Timer? _expiration;

  bool open(Uint8List bytes) {
    if (bytes.length < 8 ||
        bytes.length > 12 * 1024 * 1024 ||
        !String.fromCharCodes(bytes.take(8)).startsWith('%PDF-')) {
      return false;
    }
    clear();
    final body = web.document.body;
    if (body == null) return false;
    final link = web.HTMLAnchorElement();
    try {
      final pdf = web.Blob(<JSAny>[bytes.toJS].toJS,
          web.BlobPropertyBag(type: 'application/pdf'));
      final url = web.URL.createObjectURL(pdf);
      _url = url;
      // Revoking immediately can interrupt Safari before the new tab has
      // consumed the PDF. The timer also covers readers who leave the form open.
      _expiration = Timer(const Duration(minutes: 5), clear);
      link
        ..href = url
        ..target = '_blank'
        ..rel = 'noopener noreferrer';
      link.style.display = 'none';
      body.append(link);
      link.click();
      return true;
    } catch (_) {
      clear();
      return false;
    } finally {
      link.remove();
    }
  }

  void clear() {
    _expiration?.cancel();
    _expiration = null;
    final url = _url;
    _url = null;
    if (url != null) web.URL.revokeObjectURL(url);
  }
}
