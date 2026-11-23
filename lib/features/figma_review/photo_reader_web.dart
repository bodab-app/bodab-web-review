import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

const supportsPhotoReading = true;

Future<String> recognizePhoto(Uint8List bytes) async {
  final url = Uri.parse(web.document.baseURI).resolve('ocr/photo_ocr.mjs');
  if (url.origin != web.window.location.origin) {
    throw StateError('Photo reader must be served from this origin');
  }
  // The Flutter 3.44 SDK pinned by the app includes native ES-module import.
  // ignore: sdk_version_since
  final module = await importModule(url.toString().toJS).toDart;
  final result =
      module.callMethod<JSPromise<JSString>>('recognizePhoto'.toJS, bytes.toJS);
  return (await result.toDart).toDart;
}
