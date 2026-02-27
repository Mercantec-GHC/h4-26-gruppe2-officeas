import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/camera_capture_page.dart';
import 'read_image_bytes.dart';

/// Result of a successful image pick: raw bytes and a suggested filename.
typedef PickImageResult = ({List<int> bytes, String filename});

/// Shows a bottom sheet (Tag billede / Vælg fra galleri), then either opens
/// the camera or gallery, and returns the image bytes and filename.
///
/// Returns `null` if the user cancels (dismisses sheet or picker without selecting).
/// Throws on capture/read errors so the caller can show an error SnackBar.
Future<PickImageResult?> pickImageBytes(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tag billede'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Vælg fra galleri'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  if (source == null || !context.mounted) return null;

  if (source == ImageSource.camera) {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
    );
    if (path == null || !context.mounted) return null;

    final bytes = await readImageBytes(path);
    var filename = path.split(RegExp(r'[/\\]')).last;
    if (filename.isEmpty) filename = 'image.jpg';
    return (bytes: bytes, filename: filename);
  } else {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null || !context.mounted) return null;

    final bytes = await xfile.readAsBytes();
    return (bytes: bytes, filename: xfile.name);
  }
}
