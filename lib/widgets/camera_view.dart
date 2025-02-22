import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:trico_app_finale/services/camera_stream_service.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  final CameraStreamService _streamService = CameraStreamService();
  bool _isConnected = false;
  int _receivedBytes = 0;
  Uint8List? _currentFrame;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _streamService.connectionState.listen((connected) {
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });

    _streamService.videoStream.listen((frame) {
      if (mounted) {
        setState(() {
          _receivedBytes += frame.length;
          _currentFrame = frame;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isConnected)
            const CircularProgressIndicator()
          else if (_currentFrame != null)
            Expanded(
              child: Image.memory(
                _currentFrame!,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return child;
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Errore visualizzazione: $error');
                  return Center(
                    child: Text('Errore visualizzazione: $error'),
                  );
                },
              ),
            )
          else
            const Text('In attesa del primo frame...'),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Bytes ricevuti: $_receivedBytes',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      await _streamService.initializeVideoStream();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore connessione camera: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _streamService.dispose();
    super.dispose();
  }
}
