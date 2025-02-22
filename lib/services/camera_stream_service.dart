import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class CameraStreamService {
  Socket? _socket;
  final String ipAddress = '192.168.1.1';
  final int videoPort = 40005;

  final _streamController = StreamController<Uint8List>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<Uint8List> get videoStream => _streamController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;

  List<int> _buffer = [];

  Future<void> initializeVideoStream() async {
    try {
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
        (data) {
          print('📥 Ricevuti ${data.length} bytes');
          _streamController.add(data);
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

  void _cleanupSocket() {
    _socket?.close();
    _socket = null;
    _buffer.clear();
  }

  void dispose() {
    _cleanupSocket();
    _streamController.close();
    _connectionStateController.close();
  }
}
