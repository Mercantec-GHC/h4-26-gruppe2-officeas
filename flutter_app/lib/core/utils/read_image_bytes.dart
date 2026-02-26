import 'read_image_bytes_io.dart'
    if (dart.library.html) 'read_image_bytes_web.dart' as impl;

/// Reads image bytes from a file path (io) or blob URL (web).
/// Use this instead of File(path).readAsBytes() to support web.
Future<List<int>> readImageBytes(String pathOrUrl) =>
    impl.readImageBytes(pathOrUrl);
