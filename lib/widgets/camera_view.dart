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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _streamService.connectionState.listen((connected) {
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });

    _streamService.videoStream.listen((data) {
      if (mounted) {
        setState(() {
          _receivedBytes += data.length;
        });
      }
    });
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
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isConnected)
            const CircularProgressIndicator()
          else
            Text(
              'Connesso\nBytes ricevuti: $_receivedBytes',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          Text(
            _isConnected ? 'Stream attivo' : 'In attesa della connessione...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _streamService.dispose();
    super.dispose();
  }
}
