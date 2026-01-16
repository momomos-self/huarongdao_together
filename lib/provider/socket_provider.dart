import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/puzzle_utils.dart';

class SocketProvider with ChangeNotifier {
  IO.Socket? socket;
  String? roomId;
  bool isHost = false;
  List<dynamic> players = [];
  List<int>? gameLayout;
  int gameSize = 3;
  bool gameStarted = false;
  Map<String, dynamic> opponentData = {'time': '0.0', 'steps': 0};
  bool opponentFinished = false;
  Map<String, dynamic>? gameResult;
  String? lastError;
  
  List<dynamic> availableRooms = [];
  bool isConnected = false;
  int selectedDifficulty = 3; 

  // Initializing with a default, but letting user change it
  String serverUrl = 'http://127.0.0.1:3000'; 

  SocketProvider() {
    initSocket(serverUrl);
  }

  void setDifficulty(int size) {
    selectedDifficulty = size;
    notifyListeners();
  }

  void resetSession() {
    roomId = null;
    isHost = false;
    players = [];
    gameLayout = null;
    gameStarted = false;
    opponentData = {'time': '0.0', 'steps': 0};
    opponentFinished = false;
    gameResult = null;
    notifyListeners();
  }

  void clearGameState() {
    gameStarted = false;
    gameLayout = null;
    gameResult = null;
    opponentFinished = false;
    opponentData = {'time': '0.0', 'steps': 0};
    notifyListeners();
  }

  void initSocket(String url) {
    serverUrl = url;
    socket?.dispose();
    
    socket = IO.io(serverUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .enableForceNew()
      .build());

    socket!.onConnect((_) {
      print('Connected to $serverUrl');
      isConnected = true;
      getRooms();
      notifyListeners();
    });

    socket!.onDisconnect((_) {
      print('Disconnected');
      isConnected = false;
      notifyListeners();
    });
    
    socket!.on('roomCreated', (data) {
      roomId = data['roomId'];
      isHost = true;
      players = data['players'];
      notifyListeners();
    });

    socket!.on('roomList', (data) {
      availableRooms = data;
      notifyListeners();
    });

    socket!.on('playerJoined', (data) {
      players = data['players'];
      // If server confirms join, set roomId (server now includes roomId)
      if (data['roomId'] != null) {
        roomId = data['roomId'];
      }
      notifyListeners();
    });

    socket!.on('opponentDisconnected', (_) {
      // Mark opponent as exited/disconnected so UI can show a non-blocking notice.
      opponentData['status'] = '对手已退出';
      // Do not reset the whole session here — keep room info so local player can
      // still view results or continue local-only actions. Server will inform
      // client of room changes separately.
      notifyListeners();
    });

    socket!.on('gameStarted', (data) {
      gameLayout = List<int>.from(data['layout']);
      gameSize = data['size'] ?? 3;
      gameStarted = true;
      gameResult = null;
      opponentFinished = false;
      notifyListeners();
    });

    socket!.on('opponentUpdate', (data) {
      opponentData = data;
      notifyListeners();
    });

    socket!.on('opponentFinished', (data) {
      opponentFinished = true;
      notifyListeners();
    });

    socket!.on('gameEnded', (data) {
      gameResult = data;
      notifyListeners();
    });

    socket!.on('error', (msg) {
      print('Socket Error: $msg');
      lastError = msg?.toString();
      notifyListeners();
    });

    socket!.connect();
  }

  void getRooms() {
    socket?.emit('getRooms');
  }

  void createRoom({String? password}) {
    socket?.emit('createRoom', {'password': password, 'isPublic': true});
  }

  void joinRoom(String id, {String? password}) {
    // Emit a join request; do not set roomId until server confirms via 'playerJoined'
    socket?.emit('joinRoom', {'roomId': id, 'password': password});
    isHost = false;
  }

  void leaveRoom() {
    if (roomId != null) {
      socket?.emit('leaveRoom', {'roomId': roomId});
      // reset local session immediately
      resetSession();
      // request fresh room list to avoid stale UI (server should broadcast but ensure client refresh)
      Future.delayed(const Duration(milliseconds: 150), () => getRooms());
    }
  }

  void startGame(int size) {
    if (isHost && socket != null) {
      List<int> layout = PuzzleUtils.generateSolvableLayout(size);
      socket!.emit('startGame', {'roomId': roomId, 'layout': layout, 'size': size});
    }
  }

  void updateStatus(String time, int steps) {
    socket?.emit('updateStatus', {'roomId': roomId, 'time': time, 'steps': steps});
  }

  void finishGame(String time, int steps) {
    socket?.emit('finishGame', {'roomId': roomId, 'time': time, 'steps': steps});
  }

  // Local update helpers for LAN mode (allow other providers/pages to update opponent state)
  void setOpponentStatus(String time, int steps) {
    opponentData = {'time': time, 'steps': steps};
    notifyListeners();
  }

  void setOpponentFinished(String time, int steps) {
    opponentData = {'time': time, 'steps': steps};
    opponentFinished = true;
    notifyListeners();
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }
}
