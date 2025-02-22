import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class H264Decoder {
  static const platform = MethodChannel('com.example.trico_app/h264_decoder');
  final _frameController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get onFrame => _frameController.stream;
  bool _isInitialized = false;

  Future<void> initialize() async {
    try {
      await platform.invokeMethod('initialize');
      _isInitialized = true;

      // Ascolta i frame decodificati dalla piattaforma
      platform.setMethodCallHandler((call) async {
        if (call.method == 'onFrameDecoded') {
          final frameData = call.arguments as Uint8List;
          _frameController.add(frameData);
        }
      });
    } catch (e) {
      print('Errore inizializzazione decoder: $e');
      rethrow;
    }
  }

  Future<void> decodeFrame(Uint8List data) async {
    if (!_isInitialized) return;
    try {
      await platform.invokeMethod('decodeFrame', {'data': data});
    } catch (e) {
      print('Errore decodifica frame: $e');
    }
  }

  void dispose() {
    _frameController.close();
    platform.invokeMethod('dispose');
  }
}
