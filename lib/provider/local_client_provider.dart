import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LocalClientProvider with ChangeNotifier {
  Socket? _socket;
  bool _connected = false;
  String serverIp = '';
  int serverPort = 8888;

  final List<void Function(Map<String, dynamic>)> _messageHandlers = [];

  bool get isConnected => _connected;

  Future<bool> connectToLocalServer(String ip, int port, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      serverIp = ip;
      serverPort = port;
      _socket = await Socket.connect(ip, port, timeout: timeout);
      _connected = true;
      _socket?.listen((data) {
        try {
          final text = utf8.decode(data).trim();
          if (text.isEmpty) return;
          final msg = jsonDecode(text);
          for (var h in List.from(_messageHandlers)) {
            try { h(Map<String, dynamic>.from(msg)); } catch (_) {}
          }
        } catch (e) {
          if (kDebugMode) print('Client parse error: $e');
        }
      }, onDone: () {
        _connected = false;
        try { _socket?.destroy(); } catch (_) {}
        _socket = null;
        notifyListeners();
      }, onError: (e) {
        _connected = false;
        try { _socket?.destroy(); } catch (_) {}
        _socket = null;
        notifyListeners();
      });
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('connectToLocalServer error: $e');
      _connected = false;
      _socket = null;
      return false;
    }
  }

  void registerMessageHandler(void Function(Map<String, dynamic>) handler) {
    _messageHandlers.add(handler);
  }

  void unregisterMessageHandler(void Function(Map<String, dynamic>) handler) {
    _messageHandlers.remove(handler);
  }

  bool sendMessage(Map<String, dynamic> msg) {
    if (!_connected || _socket == null) return false;
    try {
      _socket!.add(utf8.encode(jsonEncode(msg) + '\n'));
      _socket!.flush();
      return true;
    } catch (e) {
      if (kDebugMode) print('sendMessage error: $e');
      return false;
    }
  }

  void disconnect() {
    try { _socket?.destroy(); } catch (_) {}
    _socket = null;
    _connected = false;
    notifyListeners();
  }
}
