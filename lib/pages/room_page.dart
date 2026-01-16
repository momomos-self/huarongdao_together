import "dart:async";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import 'package:uuid/uuid.dart';
// import '../utils/puzzle_utils.dart';
import '../provider/local_server_provider.dart';
import '../provider/local_client_provider.dart';
import "../provider/socket_provider.dart";
import "../provider/game_provider.dart";
import "multi_game_page.dart";

class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isNavigating = false;
  bool _errorShown = false;
  bool _showDisconnected = false;
  Timer? _disconnectTimer;
  String? _localRoomId;
  bool _localIsHost = false;
  final TextEditingController _localIpController = TextEditingController();
  bool _localServerHandlerRegistered = false;
  bool _useLocalLan = false;
  bool _localClientHandlerRegistered = false;
  void Function(Map<String, dynamic>)? _localClientMsgHandler;
  bool _localJoined = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SocketProvider>();
      // listen for socket errors to show persistent dialog
      sp.addListener(_socketErrorListener);
      if (sp.roomId != null) {
        sp.leaveRoom();
      } else {
        sp.resetSession();
      }
      _ipController.text = sp.serverUrl;
      sp.getRooms();
      // Delay showing the disconnected banner briefly to avoid a quick flash
      _disconnectTimer?.cancel();
      _disconnectTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() {
          _showDisconnected = !sp.isConnected;
        });
      });
    });
    // Ensure initState remains consistent
    // Additional initialization can be added here if needed
  }

  void _socketErrorListener() {
    final sp = context.read<SocketProvider>();
    if (!mounted) return;
    if (sp.lastError != null && !_errorShown) {
      _errorShown = true;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('网络错误'),
          content: Text(sp.lastError!),
          actions: [
            TextButton(
              onPressed: () {
                sp.clearError();
                _errorShown = false;
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            )
          ],
        ),
      );
    }
  }

  Future<int?> showDifficultyDialog() {
          int selected = 3;
          return showDialog<int>(
            context: context,
            builder: (context) {
              return StatefulBuilder(builder: (context, setState) {
                return AlertDialog(
                  title: const Text('选择难度'),
                  content: Wrap(
                    spacing: 8,
                    children: [3, 4, 5, 6].map((size) {
                      return ChoiceChip(
                        label: Text('${size}x$size'),
                        selected: selected == size,
                        onSelected: (_) => setState(() => selected = size),
                      );
                    }).toList(),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('取消')),
                    ElevatedButton(onPressed: () => Navigator.of(context).pop(selected), child: const Text('确定')),
                  ],
                );
              });
            },
          );
        }

  @override
  Widget build(BuildContext context) {
    var socketProvider = context.watch<SocketProvider>();

    if (socketProvider.gameStarted && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MultiGamePage()),
          ).then((_) {
            _isNavigating = false;
            socketProvider.clearGameState();
            socketProvider.getRooms();
          });
        }
      });
    }
    // Ensure build method remains consistent
    // Additional build logic can be added here if needed

    return Scaffold(
      appBar: AppBar(
        title: Text(socketProvider.roomId == null ? "对战大厅" : "等待对手"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (socketProvider.roomId != null) {
              // If currently in a room, leave it but stay on this page (back to lobby)
              socketProvider.leaveRoom();
              // refresh room list after leaving
              socketProvider.getRooms();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          Row(children: [const Text('局域网'), Switch(value: _useLocalLan, onChanged: (v) => setState(() => _useLocalLan = v)),]),
          if (socketProvider.roomId == null && !_useLocalLan) ...[
            IconButton(
              icon: Icon(Icons.settings, color: socketProvider.isConnected ? Colors.green : Colors.red),
              onPressed: () => _showIpDialog(context, socketProvider),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => socketProvider.getRooms(),
            ),
          ]
        ],
      ),
          body: _useLocalLan ? _buildLocalLobby() : (socketProvider.roomId == null ? _buildLobby(socketProvider) : _buildWaitingRoom(socketProvider)),
    );
  }

  // removed server-dependent _waitForRoomId; using pure P2P invite flow instead

  Widget _buildLocalLobby() {
    final localServer = context.watch<LocalServerProvider>();
    final localClient = context.watch<LocalClientProvider>();

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前本机 IP: ${localServer.serverIp}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              if (localServer.isServerRunning) Text('本地服务: ${localServer.serverIp}:${localServer.listenPort} 连接数: ${localServer.clientCount}', style: const TextStyle(color: Colors.black54)),
              if (localClient.isConnected) Text('已连接到主机: ${localClient.serverIp}:${localClient.serverPort}', style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text('局域网 本地 C/S (端口: 8888)', style: TextStyle(color: Colors.grey[700])),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (!localServer.isServerRunning) {
                  final ok = await context.read<LocalServerProvider>().startLocalServer();
                    if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已启动本地服务 ${context.read<LocalServerProvider>().serverIp}:${context.read<LocalServerProvider>().listenPort}')));
                    // register a join handler once that records client info and auto-accepts
                    if (!_localServerHandlerRegistered) {
                      context.read<LocalServerProvider>().registerMessageHandler((msg, socket) {
                        try {
                          if (msg['type'] == 'join_request') {
                            // record client info (name/roomId)
                            context.read<LocalServerProvider>().updateClientInfo(socket!, {'name': msg['name'] ?? '', 'roomId': msg['roomId']});
                            // auto accept and inform the client
                            context.read<LocalServerProvider>().sendToSocket(socket, {'type': 'join_accept', 'roomId': msg['roomId']});
                          }
                        } catch (_) {}
                      });
                      _localServerHandlerRegistered = true;
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('启动本地服务失败')));
                  }
                } else {
                  context.read<LocalServerProvider>().stopLocalServer();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('本地服务已停止')));
                }
              },
              child: Text(localServer.isServerRunning ? '停止本地服务' : '创建本地房间 (作为服务端)'),
            ),
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [Icon(Icons.wifi_tethering, color: Colors.blue), SizedBox(width: 8), Text("连接到主机", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _localIpController, decoration: const InputDecoration(hintText: '输入主机 IP (例如 192.168.43.1)'))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final ip = _localIpController.text.trim();
                  if (ip.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入主机 IP')));
                    return;
                  }
                  final client = context.read<LocalClientProvider>();
                  final ok = await client.connectToLocalServer(ip, 8888);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('连接主机失败')));
                    return;
                  }
                  // register client message handler once
                  if (!_localClientHandlerRegistered) {
                    _localClientMsgHandler = (msg) {
                      try {
                        final t = msg['type'];
                        if (t == 'join_accept') {
                          setState(() {
                            _localJoined = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('主机已接受加入')));
                        } else if (t == 'start') {
                          // host started the game; client should start and navigate
                          try {
                            final size = (msg['size'] is int) ? msg['size'] : int.parse(msg['size'].toString());
                            final layout = msg['layout'] != null ? List<int>.from(msg['layout']) : null;
                            final gp = context.read<GameProvider>();
                            gp.startGame(size, initialLayout: layout, isMultiplayer: true);
                            if (!mounted) return;
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiGamePage(useP2P: true)));
                          } catch (_) {}
                        }
                      } catch (_) {}
                    };
                    client.registerMessageHandler(_localClientMsgHandler!);
                    _localClientHandlerRegistered = true;
                  }
                  _localRoomId = const Uuid().v4();
                  client.sendMessage({'type': 'join_request', 'roomId': _localRoomId, 'name': 'client'});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已连接到主机，等待开始')));
                },
                child: const Text('连接'),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (localServer.isServerRunning) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('已连接设备: ${localServer.clientCount}'), ElevatedButton(onPressed: localServer.clientCount>0?() async {
                  final size = await showDifficultyDialog();
                  if (size == null) return;
                  // start local host game and broadcast start to clients
                  final gp = context.read<GameProvider>();
                  gp.startGame(size, isMultiplayer: true);
                  context.read<LocalServerProvider>().sendStart(size, layout: gp.layout);
                  // navigate to multi-game page in local mode
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiGamePage(useP2P: true)));
                }:null, child: const Text('开始游戏'))]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('连接列表', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 80,
                  child: ListView(
                    children: localServer.clients.map((c) => ListTile(title: Text(c['name']?.toString() ?? c['ip'] ?? '未知'), subtitle: Text(c['ip'] ?? ''), dense: true)).toList(),
                  ),
                )
              ],
            ),
          ),
        ],
        const Spacer(),
      ],
    );
  }

  Widget _buildLobby(SocketProvider sp) {
    return Column(
      children: [
        if (!sp.isConnected && _showDisconnected)
          Container(
            color: Colors.red.shade100,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            child: const Text("服务器未连接，请在右上角设置 IP", textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: sp.isConnected ? () => _showCreateRoomDialog(sp) : null,
              icon: const Icon(Icons.add),
              label: const Text("创建房间"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [Icon(Icons.list, color: Colors.blue), SizedBox(width: 8), Text("可用房间", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        ),
        Expanded(
          child: sp.availableRooms.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, size: 40, color: Colors.grey), Text("当前没有房间，快去创建一个吧", style: TextStyle(color: Colors.grey))]))
              : ListView.builder(
                  itemCount: sp.availableRooms.length,
                  itemBuilder: (context, index) {
                    final room = sp.availableRooms[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Text(room["id"][0])),
                        title: Text("房间: ${room["id"]}", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("人数: ${room["playerCount"]}/2 ${room["hasPassword"] ? " 有密码" : ""}"),
                        trailing: ElevatedButton(
                          onPressed: () => _showJoinDialog(sp, room["id"], room["hasPassword"]),
                          child: const Text("加入"),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWaitingRoom(SocketProvider sp) {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Text("房间 ID", style: TextStyle(color: Colors.grey)),
        Text(sp.roomId!, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.blue)),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _playerCard("你自己", true),
            const Text("VS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
            _playerCard("对手", sp.players.length > 1),
          ],
        ),
        const SizedBox(height: 40),
        if (sp.isHost && sp.players.length == 2) ...[
          const Text("选择难度", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [3, 4, 5, 6].map((size) {
              bool selected = sp.selectedDifficulty == size;
              return ChoiceChip(
                label: Text("${size}x$size"),
                selected: selected,
                onSelected: (val) {
                  if (val) sp.setDifficulty(size);
                },
              );
            }).toList(),
          ),
        ],
        const Spacer(),
        if (sp.isHost)
          Padding(
            padding: const EdgeInsets.all(32),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: sp.players.length == 2 ? () => sp.startGame(sp.selectedDifficulty) : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text("开始游戏", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        else
          const Padding(padding: EdgeInsets.only(bottom: 60), child: Text("等待房主点击开始...", style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey))),
      ],
    );
  }

  Widget _playerCard(String name, bool joined) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: joined ? Colors.blue : Colors.grey, width: 2)),
          child: CircleAvatar(radius: 35, backgroundColor: joined ? Colors.blue.shade50 : Colors.grey.shade100, child: Icon(Icons.person, size: 40, color: joined ? Colors.blue : Colors.grey)),
        ),
        const SizedBox(height: 12),
        Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: joined ? Colors.black : Colors.grey)),
        Text(joined ? "已进入" : "等待加入", style: TextStyle(fontSize: 12, color: joined ? Colors.green : Colors.grey)),
      ],
    );
  }

  void _showIpDialog(BuildContext context, SocketProvider sp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("服务器设置"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("请输入 Node.js 后端服务器地址", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(controller: _ipController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "http://192.168.x.x:3000")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          ElevatedButton(
            onPressed: () {
              sp.initSocket(_ipController.text);
              Navigator.pop(context);
            },
            child: const Text("重新连接"),
          ),
        ],
      ),
    );
  }

  void _showCreateRoomDialog(SocketProvider sp) {
    _passController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("创建房间"),
        content: TextField(controller: _passController, decoration: const InputDecoration(hintText: "密码 (选填，留空则公开)", prefixIcon: Icon(Icons.lock_outline))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          ElevatedButton(
            onPressed: () {
              sp.createRoom(password: _passController.text.isEmpty ? null : _passController.text);
              Navigator.pop(context);
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(SocketProvider sp, String id, bool hasPass) {
    if (!hasPass) {
      sp.joinRoom(id);
      return;
    }
    _passController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("房间加密"),
        content: TextField(controller: _passController, decoration: const InputDecoration(hintText: "请输入密码"), obscureText: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          ElevatedButton(
            onPressed: () {
              sp.joinRoom(id, password: _passController.text);
              Navigator.pop(context);
            },
            child: const Text("验证并加入"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      context.read<SocketProvider>().removeListener(_socketErrorListener);
    } catch (_) {}
    // unregister local client/server handlers
    try {
      if (_localClientHandlerRegistered && _localClientMsgHandler != null) {
        context.read<LocalClientProvider>().unregisterMessageHandler(_localClientMsgHandler!);
        _localClientHandlerRegistered = false;
        _localClientMsgHandler = null;
      }
    } catch (_) {}
    try {
      if (_localServerHandlerRegistered) {
        context.read<LocalServerProvider>().unregisterMessageHandler((msg, sock) {});
        _localServerHandlerRegistered = false;
      }
    } catch (_) {}
    _disconnectTimer?.cancel();
    _ipController.dispose();
    _passController.dispose();
    super.dispose();
  }
}
