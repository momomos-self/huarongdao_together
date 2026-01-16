// abandoned file
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import '../utils/puzzle_utils.dart';

class P2PProvider with ChangeNotifier {
  final int discoveryPort = 41234;
  final int signalingPort = 41235;
  int? discoveryPortActual;
  int? signalingPortActual;
  RawDatagramSocket? _discoverySocket;
  RawDatagramSocket? _signalingSocket;
  Timer? _broadcastTimer;
  String localId = const Uuid().v4();
  String? localName;
  String localIp = "Unknown";

  // discovered peers: list of {id, name, address, port, lastSeen}
  final List<Map<String, dynamic>> discovered = [];

  // Active peer connection / data channel
  RTCPeerConnection? _pc;
  RTCDataChannel? _dc;
  bool connected = false;

  // Message handlers: allow multiple handlers and unregister
  final List<void Function(Map<String, dynamic>)> _messageHandlers = [];
  // Backwards-compatible last-registered single handler
  void Function(Map<String, dynamic>)? onMessage;
  void Function(List<int> layout, int size)? onStart;

  P2PProvider({this.localName}) {
    startDiscovery();
    startSignalingListener();
  }

  // Helper: try binding to candidate ports, fallback to system-assigned (0)
  Future<RawDatagramSocket> _bindWithFallback(List<int> candidates, String purpose) async {
    for (var p in candidates) {
      try {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, p, reuseAddress: true);
        socket.broadcastEnabled = true;
        debugPrint('[_bindWithFallback] $purpose bound on port ${socket.port} (requested $p)');
        return socket;
      } catch (e) {
        debugPrint('[_bindWithFallback] failed to bind $purpose on $p: $e');
      }
    }
    throw Exception('Unable to bind socket for $purpose');
  }

  // Start periodic UDP broadcast announcing presence
  Future<void> startDiscovery() async {
    if (kIsWeb) return;
    
    // 1. Android 强开多播锁
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        const channel = MethodChannel('huarongdao.p2p/multicast');
        await channel.invokeMethod('acquireMulticastLock');
      } catch (e) {
        debugPrint('Multicast lock error: $e');
      }
    }

    try {
      // 2. 绑定发现端口（尝试固定端口，失败回退到系统分配）
      _discoverySocket = await _bindWithFallback([discoveryPort, 0], 'discovery');
      _discoverySocket!.broadcastEnabled = true;
      _discoverySocket!.listen(_handleDiscoveryEvent);
      discoveryPortActual = _discoverySocket!.port;
      debugPrint('Discovery socket bound on port $discoveryPortActual');

      // 3. 开启定时广播
      _broadcastTimer?.cancel();
      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        try {
          final interfaces = await NetworkInterface.list();
          List<String> broadcastTargets = ["255.255.255.255"];
          
          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
                localIp = addr.address; // 简单记一个非回环 IP
                final parts = addr.address.split('.');
                if (parts.length == 4) {
                  broadcastTargets.add("${parts[0]}.${parts[1]}.${parts[2]}.255");
                }
              }
            }
          }
          notifyListeners();

          // 4. 清理陈旧节点（超过 10 秒未收到心跳）
          final beforeSize = discovered.length;
          discovered.removeWhere((d) {
            final lastSeen = d['lastSeen'] as DateTime;
            return DateTime.now().difference(lastSeen).inSeconds > 10;
          });
          if (discovered.length != beforeSize) {
            notifyListeners();
          }

          final msg = jsonEncode({
            'type': 'presence',
            'id': localId,
            'name': localName ?? '玩家${localId.substring(0, 4)}',
            'signalPort': signalingPortActual ?? signalingPort,
            'discoveryPort': discoveryPortActual ?? discoveryPort,
          });
          final data = utf8.encode(msg);

          debugPrint('Broadcast targets: ${broadcastTargets.toSet().toList()}');
          for (var target in broadcastTargets.toSet()) {
            try {
              debugPrint('Sending presence to $target:$discoveryPort');
              _discoverySocket?.send(data, InternetAddress(target), discoveryPort);
            } catch (e) {
              debugPrint('Send to $target error: $e');
            }
          }
        } catch (e) {
          debugPrint('Discovery loop error: $e');
        }
      });
    } catch (e) {
      debugPrint('Discovery start error: $e');
    }
  }

  void _handleDiscoveryEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final dg = _discoverySocket!.receive();
      if (dg == null) return;
      try {
        final rawData = utf8.decode(dg.data);
        debugPrint('Received UDP from ${dg.address.address}: $rawData');
        final json = jsonDecode(rawData);
        if (json['type'] == 'presence' && json['id'] != localId) {
          final addr = dg.address.address;
          final id = json['id'];
          final name = json['name'];
          final port = json['signalPort'] ?? json['discoveryPort'] ?? signalingPort;
          final now = DateTime.now();
          final idx = discovered.indexWhere((d) => d['id'] == id);
          if (idx >= 0) {
            discovered[idx]['lastSeen'] = now;
            discovered[idx]['address'] = addr;
            discovered[idx]['port'] = port;
          } else {
            debugPrint('New Peer Discovered: $name at $addr');
            discovered.add({'id': id, 'name': name, 'address': addr, 'port': port, 'lastSeen': now});
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Discovery parse error from ${dg.address.address}: $e');
      }
    }
  }

  // Signaling listener for offers/answers/candidates on UDP
  Future<void> startSignalingListener() async {
    try {
      _signalingSocket = await _bindWithFallback([signalingPort, 0], 'signaling');
      signalingPortActual = _signalingSocket!.port;
      _signalingSocket!.listen(_handleSignalingEvent);
      debugPrint('Signaling socket bound on port $signalingPortActual');
    } catch (e) {
      if (kDebugMode) print('Signaling bind error: $e');
    }
  }

  void _handleSignalingEvent(RawSocketEvent event) async {
    if (event != RawSocketEvent.read) return;
    final dg = _signalingSocket!.receive();
    if (dg == null) return;
    try {
      final msg = jsonDecode(utf8.decode(dg.data));
      final from = dg.address.address;
      final type = msg['type'];
      if (type == 'offer') {
        await _onOffer(msg['sdp'], from);
      } else if (type == 'answer') {
        await _onAnswer(msg['sdp']);
      } else if (type == 'candidate') {
        await _onCandidate(msg['candidate']);
      }
    } catch (e) {
      if (kDebugMode) print('Signaling parse error: $e');
    }
  }

  Future<void> _onOffer(String sdp, String fromAddress) async {
    // Create PC, set remote, create answer, send back
    await _createPeerConnection();
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    final msg = jsonEncode({'type': 'answer', 'sdp': answer.sdp});
    _signalingSocket!.send(utf8.encode(msg), InternetAddress(fromAddress), signalingPort);
    notifyListeners();
  }

  Future<void> _onAnswer(String sdp) async {
    if (_pc == null) return;
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> _onCandidate(Map<String, dynamic> candidate) async {
    if (_pc == null) return;
    try {
      final c = RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']);
      await _pc!.addCandidate(c);
    } catch (e) {
      if (kDebugMode) print('Add candidate error: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    if (_pc != null) return;
    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    };
    final pc = await createPeerConnection(config);
    pc.onIceCandidate = (candidate) {
      final msg = jsonEncode({'type': 'candidate', 'candidate': {'candidate': candidate.candidate, 'sdpMid': candidate.sdpMid, 'sdpMLineIndex': candidate.sdpMLineIndex}});
      // broadcast candidate - in LAN case remote address should be known when initiating
      // For simplicity we broadcast to discovered peers (could be optimized)
      for (var p in discovered) {
        try {
          final portToUse = (p['port'] ?? signalingPortActual ?? signalingPort) as int;
          _signalingSocket?.send(utf8.encode(msg), InternetAddress(p['address']), portToUse);
        } catch (_) {}
      }
    };

    pc.onDataChannel = (dc) {
      _setupDataChannel(dc);
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        connected = true;
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected || 
                 state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        connected = false;
      }
      notifyListeners();
    };

    final dcInit = RTCDataChannelInit();
    final dc = await pc.createDataChannel('game', dcInit);
    _setupDataChannel(dc);

    _pc = pc;
    notifyListeners();
  }

  void _setupDataChannel(RTCDataChannel dc) {
    _dc = dc;
    _dc?.onDataChannelState = (state) {
      connected = (state == RTCDataChannelState.RTCDataChannelOpen);
      notifyListeners();
    };
    _dc?.onMessage = (msg) {
      try {
        final m = jsonDecode(msg.text);
        // dispatch to registered handlers first
        for (var h in List.from(_messageHandlers)) {
          try {
            h(Map<String, dynamic>.from(m));
          } catch (_) {}
        }
        if (onMessage != null) onMessage!(Map<String, dynamic>.from(m));
        if (m['type'] == 'request_start') {
          final size = m['size'] ?? 3;
          final layout = PuzzleUtils.generateSolvableLayout(size);
          sendMessage({'type': 'start', 'layout': layout, 'size': size});
          if (onStart != null) onStart!(List<int>.from(layout), size);
        } else if (m['type'] == 'start') {
          if (onStart != null) onStart!(List<int>.from(m['layout']), m['size'] ?? 3);
        }
      } catch (_) {}
    };
  }

  // Initiate connection to a discovered peer by IP
  // Returns true if connection (data channel) is established within [timeout]
  Future<bool> connectToPeer(String address, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      await _createPeerConnection();
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      final msg = jsonEncode({'type': 'offer', 'sdp': offer.sdp});
      // send offer to peer's signaled port if known in discovered list
      final p = discovered.firstWhere((d) => d['address'] == address, orElse: () => {});
      int portToUse = signalingPort;
      if (p.isNotEmpty) {
        portToUse = (p['port'] ?? signalingPortActual ?? signalingPort) as int;
      } else {
        portToUse = signalingPortActual ?? signalingPort;
      }
      debugPrint('Sending offer to $address:$portToUse');
      _signalingSocket?.send(utf8.encode(msg), InternetAddress(address), portToUse);

      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        if (connected) return true;
        await Future.delayed(const Duration(milliseconds: 200));
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('connectToPeer error: $e');
      return false;
    }
  }

  // Register callback to receive parsed messages (adds to handler list)
  void registerMessageHandler(void Function(Map<String, dynamic>) handler) {
    onMessage = handler;
    _messageHandlers.add(handler);
  }

  // Unregister a previously registered handler
  void unregisterMessageHandler(void Function(Map<String, dynamic>) handler) {
    _messageHandlers.remove(handler);
    if (onMessage == handler) {
      onMessage = _messageHandlers.isNotEmpty ? _messageHandlers.last : null;
    }
  }

  void registerStartHandler(void Function(List<int>, int) handler) {
    onStart = handler;
  }

  /// Send a message and wait for an acknowledgement (ackType) within timeout.
  /// Returns true when ack received, false on timeout/failure.
  Future<bool> sendMessageWithAck(Map<String, dynamic> msg, {String ackType = 'invite_ack', String? matchRoomId, Duration timeout = const Duration(seconds: 3)}) async {
    final completer = Completer<bool>();

    void ackHandler(Map<String, dynamic> m) {
      try {
        if (m['type'] == ackType && (matchRoomId == null || m['roomId'] == matchRoomId)) {
          if (!completer.isCompleted) completer.complete(true);
          unregisterMessageHandler(ackHandler);
        }
      } catch (_) {}
    }

    registerMessageHandler(ackHandler);
    sendMessage(msg);

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
        unregisterMessageHandler(ackHandler);
      }
    });

    return completer.future;
  }

  // Send a JSON message over data channel (if available)
  void sendMessage(Map<String, dynamic> msg) {
    final txt = jsonEncode(msg);
    try {
      if (_dc != null) {
        _dc!.send(RTCDataChannelMessage(txt));
      } else if (_signalingSocket != null) {
        // fallback: send as UDP signaling if data channel not ready
        for (var p in discovered) {
          try {
            _signalingSocket!.send(utf8.encode(txt), InternetAddress(p['address']), signalingPort);
          } catch (_) {}
        }
      }
    } catch (e) {
      if (kDebugMode) print('P2P send error: $e');
    }
  }

  // Request the remote to start (initiator asks host to generate layout)
  void requestStart({int size = 3}) {
    sendMessage({'type': 'request_start', 'size': size});
  }

  void sendData(String text) {
    _dc?.send(RTCDataChannelMessage(text));
  }

  Future<void> disposeProvider() async {
    _broadcastTimer?.cancel();
    _discoverySocket?.close();
    _signalingSocket?.close();
    await _pc?.close();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        const channel = MethodChannel('huarongdao.p2p/multicast');
        await channel.invokeMethod('releaseMulticastLock');
      } catch (e) {
        if (kDebugMode) print('Multicast lock release failed: $e');
      }
    }
  }
}
