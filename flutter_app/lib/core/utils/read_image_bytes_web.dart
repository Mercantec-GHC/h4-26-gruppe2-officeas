import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Reads image bytes from a blob URL (e.g. from camera on web).
Future<List<int>> readImageBytes(String pathOrUrl) async {
  if (pathOrUrl.startsWith('blob:')) {
    final completer = Completer<List<int>>();
    final request = html.HttpRequest();

    request.open('GET', pathOrUrl);
    request.responseType = 'arraybuffer';

    request.onLoad.listen((_) {
      final buffer = request.response as ByteBuffer?;

      if (buffer != null) {
        completer.complete(buffer.asUint8List().toList());
      } else {
        completer.completeError(Exception('Failed to load image'));
      }
    });

    request.onError.listen((e) => completer.completeError(e));
    request.send();

    return completer.future;
  }
  throw UnsupportedError(
    'Only blob: URLs are supported on web. Use image_picker for file paths.',
  );
}
