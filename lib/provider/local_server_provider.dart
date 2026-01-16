import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LocalServerProvider with ChangeNotifier {
  ServerSocket? _serverSocket;
  final List<Socket> _clientSockets = [];
  final Map<Socket, Map<String, dynamic>> _clientInfo = {};
  String _serverIp = 'Unknown';
  int _listenPort = 8888;
  bool _isServerRunning = false;

  // message handlers
  final List<void Function(Map<String, dynamic>, Socket?)> _messageHandlers = [];

  bool get isServerRunning => _isServerRunning;
  String get serverIp => _serverIp;
  int get listenPort => _listenPort;
  int get clientCount => _clientSockets.length;
  List<Map<String, dynamic>> get clients => _clientInfo.values.toList();

  Future<bool> startLocalServer({int port = 8888}) async {
    try {
      _listenPort = port;
      _serverIp = await _getLocalIpAddress();
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, _listenPort);
      _isServerRunning = true;
      _serverSocket?.listen(_handleClient);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('Local server start error: $e');
      return false;
    }
  }

  void _handleClient(Socket client) {
    _clientSockets.add(client);
    // initialize client info
    _clientInfo[client] = {
      'id': client.hashCode.toString(),
      'ip': client.remoteAddress.address,
      'name': '',
    };
    notifyListeners();
    client.listen((data) {
      try {
        final text = utf8.decode(data).trim();
        if (text.isEmpty) return;
        final msg = jsonDecode(text);
        for (var h in List.from(_messageHandlers)) {
          try {
            h(Map<String, dynamic>.from(msg), client);
          } catch (_) {}
        }
      } catch (e) {
        if (kDebugMode) print('Client data parse error: $e');
      }
    }, onDone: () {
      _clientSockets.remove(client);
      _clientInfo.remove(client);
      try { client.destroy(); } catch (_) {}
      notifyListeners();
    }, onError: (err) {
      _clientSockets.remove(client);
      _clientInfo.remove(client);
      try { client.destroy(); } catch (_) {}
      notifyListeners();
    });
  }

  void updateClientInfo(Socket client, Map<String, dynamic> info) {
    final cur = _clientInfo[client] ?? {};
    cur.addAll(info);
    _clientInfo[client] = cur;
    notifyListeners();
  }

  void registerMessageHandler(void Function(Map<String, dynamic>, Socket?) handler) {
    _messageHandlers.add(handler);
  }

  void unregisterMessageHandler(void Function(Map<String, dynamic>, Socket?) handler) {
    _messageHandlers.remove(handler);
  }

  void sendToAll(Map<String, dynamic> msg, {Socket? exclude}) {
    final txt = jsonEncode(msg) + '\n';
    final data = utf8.encode(txt);
    for (var s in List.from(_clientSockets)) {
      if (exclude != null && s == exclude) continue;
      try {
        s.add(data);
        s.flush();
      } catch (_) {}
    }
  }

  void sendStart(int size, {List<int>? layout}) {
    final payload = <String, dynamic>{'type': 'start', 'size': size};
    if (layout != null) payload['layout'] = layout;
    sendToAll(payload);
  }

  void sendToSocket(Socket? client, Map<String, dynamic> msg) {
    if (client == null) return;
    try {
      client.add(utf8.encode(jsonEncode(msg) + '\n'));
      client.flush();
    } catch (_) {}
  }

  void stopLocalServer() {
    _isServerRunning = false;
    for (var c in List.from(_clientSockets)) {
      try { c.destroy(); } catch (_) {}
    }
    _clientSockets.clear();
    try { _serverSocket?.close(); } catch (_) {}
    _serverSocket = null;
    notifyListeners();
  }

  Future<String> _getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var address in interface.addresses) {
          if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
            return address.address;
          }
        }
      }
    } catch (_) {}
    return '0.0.0.0';
  }
}
