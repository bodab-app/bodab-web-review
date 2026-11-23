import 'dart:typed_data';

const supportsPhotoReading = false;
Future<String> recognizePhoto(Uint8List bytes) =>
    Future.error(UnsupportedError('Photo text recognition is unavailable'));
