import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Full-screen camera capture page. Pops with the captured image path (or blob URL on web).
class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  bool _isReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final first = cameras.isNotEmpty ? cameras.first : null;
      if (first == null) {
        setState(() => _error = 'No cameras available');
        return;
      }
      _controller = CameraController(
        first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final xfile = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(xfile.path);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error taking picture: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: _error != null
          ? Center(child: Text('Camera error: $_error'))
          : !_isReady
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    CameraPreview(_controller!),
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: FloatingActionButton(
                          onPressed: _takePicture,
                          child: const Icon(Icons.camera),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
