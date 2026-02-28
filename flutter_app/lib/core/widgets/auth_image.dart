import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Displays an image from a URL that requires Authorization header.
/// Uses the provided [token] for Bearer auth.
class AuthImage extends StatefulWidget {
  final String imageUrl;
  final String? token;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AuthImage({
    super.key,
    required this.imageUrl,
    required this.token,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends State<AuthImage> {
  Future<Uint8List?>? _future;

  @override
  void didUpdateWidget(AuthImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.token != widget.token) {
      _future = _fetchImage();
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _fetchImage();
  }

  Future<Uint8List?> _fetchImage() async {
    if (widget.imageUrl.isEmpty ||
        widget.token == null ||
        widget.token!.isEmpty) {
      return null;
    }

    try {
      final dio = Dio(
        BaseOptions(
          headers: {'Authorization': 'Bearer ${widget.token}'},
          responseType: ResponseType.bytes,
        ),
      );

      final response = await dio.get(widget.imageUrl);

      if (response.data is Uint8List) return response.data as Uint8List;

      if (response.data is List<int>) {
        return Uint8List.fromList(response.data as List<int>);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final bytes = snapshot.data;

        if (bytes == null || bytes.isEmpty) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          );
        }
        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        );
      },
    );
  }
}
