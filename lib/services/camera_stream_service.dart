import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';

class CameraStreamService {
  Socket? _socket;
  final String ipAddress = '192.168.1.1';
  final int videoPort = 40005;

  final _streamController = StreamController<Uint8List>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<Uint8List> get videoStream => _streamController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;

  List<int> _buffer = [];
  File? _tempFile;
  bool _isProcessing = false;

  Future<void> initializeVideoStream() async {
    try {
      // Crea file temporaneo per il buffer
      final tempDir = await Directory.systemTemp.createTemp('h264_stream');
      _tempFile = File('${tempDir.path}/stream.h264');

      _socket = await Socket.connect(ipAddress, videoPort,
          timeout: const Duration(seconds: 20));

      final initPacket = Uint8List(12);
      initPacket[0] = 0x5f;
      initPacket[1] = 0x6f;
      initPacket[2] = 0x00;
      initPacket[3] = 0x00;

      _socket!.add(initPacket);
      _connectionStateController.add(true);

      _socket!.listen(
        (data) async {
          print('📥 Ricevuti ${data.length} bytes');
          _buffer.addAll(data);

          // Processa il buffer quando raggiunge una certa dimensione
          if (_buffer.length > 1024 * 50 && !_isProcessing) {
            // 50KB
            await _processBuffer();
          }
        },
        onError: (error) {
          print('❌ Errore nella ricezione: $error');
          _connectionStateController.add(false);
          _cleanupSocket();
        },
        onDone: () {
          print('⚠️ Connessione chiusa');
          _connectionStateController.add(false);
          _cleanupSocket();
        },
      );
    } catch (e) {
      print('❌ Errore nella connessione: $e');
      _connectionStateController.add(false);
      _cleanupSocket();
      rethrow;
    }
  }

  Future<void> _processBuffer() async {
    _isProcessing = true;
    try {
      // Salva il buffer corrente nel file
      await _tempFile!.writeAsBytes(_buffer);
      _buffer.clear();

      // Crea una directory temporanea per i frames
      final framesDir = await Directory.systemTemp.createTemp('frames');
      final outputPath = '${framesDir.path}/frame_%d.jpg';

      // Converti H264 in frames JPEG
      final command = '''
        -i ${_tempFile!.path} 
        -vf fps=30 
        -f image2 
        -qscale:v 2
        $outputPath
      '''
          .replaceAll('\n', ' ');

      await FFmpegKit.execute(command).then((session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          // Leggi il frame più recente
          final frames = await framesDir.list().toList();
          if (frames.isNotEmpty) {
            // Prendi l'ultimo frame generato
            final lastFrame = frames.last;
            if (lastFrame is File) {
              final frameData = await lastFrame.readAsBytes();
              _streamController.add(frameData);
            }
          }
          // Pulisci la directory dei frames
          await framesDir.delete(recursive: true);
        } else {
          print('❌ Errore FFmpeg: ${await session.getFailStackTrace()}');
        }
      });
    } catch (e) {
      print('❌ Errore nel processing: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _cleanupSocket() {
    _socket?.close();
    _socket = null;
    _buffer.clear();
    _tempFile?.parent.delete(recursive: true);
    _tempFile = null;
  }

  void dispose() {
    _cleanupSocket();
    _streamController.close();
    _connectionStateController.close();
  }
}
