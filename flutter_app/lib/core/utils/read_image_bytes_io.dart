import 'dart:io';

Future<List<int>> readImageBytes(String path) async {
  final bytes = await File(path).readAsBytes();
  return bytes;
}
