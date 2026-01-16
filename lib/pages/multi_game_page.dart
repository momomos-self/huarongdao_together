import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io';
import '../utils/color_ext.dart';
import 'package:provider/provider.dart';
import '../provider/game_provider.dart';
import '../provider/socket_provider.dart';
import '../provider/local_client_provider.dart';
import '../provider/local_server_provider.dart';

class _TileImagePainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;
  _TileImagePainter(this.image, this.srcRect);

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant _TileImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.srcRect != srcRect;
  }
}

class MultiGamePage extends StatefulWidget {
  final bool useP2P;
  const MultiGamePage({super.key, this.useP2P = false});

  @override
  State<MultiGamePage> createState() => _MultiGamePageState();
}

class _MultiGamePageState extends State<MultiGamePage> {
  bool _dialogShown = false;
  late GameProvider _gameProv;
  late SocketProvider _socketProv;
  LocalClientProvider? _localClientProv;
  LocalServerProvider? _localServerProv;
  void Function(Map<String, dynamic>, Socket?)? _localServerMsgHandler;
  bool _localFinished = false;
  double? _localFinishTime;
  int? _localFinishSteps;

  @override
  void initState() {
    super.initState();
    _gameProv = context.read<GameProvider>();
    _socketProv = context.read<SocketProvider>();
    if (widget.useP2P) {
      _localClientProv = context.read<LocalClientProvider>();
      _localServerProv = context.read<LocalServerProvider>();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.useP2P) {
        _gameProv.startGame(
          _socketProv.gameSize,
          initialLayout: _socketProv.gameLayout,
          isMultiplayer: true,
        );
        // Listen to socket changes to show results
        _socketProv.addListener(_socketListener);
      } else {
        // Local client/server handlers
        _localClientProv = context.read<LocalClientProvider>();
        _localClientProv?.registerMessageHandler(_onP2PMessage);
        _localServerProv = context.read<LocalServerProvider>();
        // server side receives messages from clients; handle 'move' or other messages
        _localServerMsgHandler = (msg, socket) {
          try {
            // server forwards client moves/status/finish to other clients and updates host UI
            final t = msg['type'];
            if (t == 'move') {
              _localServerProv?.sendToAll(msg, exclude: socket);
            } else if (t == 'status') {
              final time = msg['time']?.toString() ?? '0.0';
              final steps = msg['steps'] ?? 0;
              _socketProv.setOpponentStatus(time, steps);
              // forward to other clients so everyone sees opponent status (exclude original sender)
              _localServerProv?.sendToAll(msg, exclude: socket);
            } else if (t == 'finish') {
              final time = msg['time']?.toString() ?? '0.0';
              final steps = msg['steps'] ?? 0;
              _socketProv.setOpponentFinished(time, steps);
              _localServerProv?.sendToAll(msg, exclude: socket);
            }
          } catch (_) {}
        };
        _localServerProv?.registerMessageHandler(_localServerMsgHandler!);
      }

      // Listen to game changes to sync with opponent
      _gameProv.addListener(_syncStatus);
    });
  }

  void _syncStatus() {
    if (!mounted) return;
    if (widget.useP2P) {
      // local C/S mode
      if (_localServerProv != null && _localServerProv!.isServerRunning) {
        if (!_gameProv.isGameOver) {
          _localServerProv!.sendToAll({'type': 'status', 'time': _gameProv.timeString, 'steps': _gameProv.steps});
        } else {
          _localServerProv!.sendToAll({'type': 'finish', 'time': _gameProv.timeString, 'steps': _gameProv.steps});
          if (!_localFinished) {
            _localFinished = true;
            try {
              _localFinishTime = double.parse(_gameProv.timeString);
            } catch (_) {
              _localFinishTime = 0.0;
            }
            _localFinishSteps = _gameProv.steps;
          }
          // if we are host, decide winner (host authoritative)
          if (_localServerProv != null && _localServerProv!.isServerRunning) {
            _decideWinnerAsHostWithDelay();
          }
        }
      } else if (_localClientProv != null && _localClientProv!.isConnected) {
        if (!_gameProv.isGameOver) {
          _localClientProv!.sendMessage({'type': 'status', 'time': _gameProv.timeString, 'steps': _gameProv.steps});
        } else {
          _localClientProv!.sendMessage({'type': 'finish', 'time': _gameProv.timeString, 'steps': _gameProv.steps});
          if (!_localFinished) {
            _localFinished = true;
            try {
              _localFinishTime = double.parse(_gameProv.timeString);
            } catch (_) {
              _localFinishTime = 0.0;
            }
            _localFinishSteps = _gameProv.steps;
          }
          // clients should wait for host to announce final result
        }
      }
    } else {
      if (!_gameProv.isGameOver) {
        _socketProv.updateStatus(_gameProv.timeString, _gameProv.steps);
      } else {
        _socketProv.finishGame(_gameProv.timeString, _gameProv.steps);
      }
    }
  }

  void _socketListener() {
    if (!mounted) return;
    if (_socketProv.gameResult != null && !_dialogShown) {
      _dialogShown = true;
      _showResultDialog(_socketProv.gameResult!);
    }
  }

  void _onP2PMessage(Map<String, dynamic> m) {
    if (!mounted) return;
    final type = m['type'];
    if (type == 'start') {
      try {
        final size = (m['size'] is int) ? m['size'] : int.parse(m['size'].toString());
        final layout = m['layout'] != null ? List<int>.from(m['layout']) : null;
        _gameProv.startGame(size, initialLayout: layout, isMultiplayer: true);
      } catch (_) {}
      return;
    }
    if (type == 'move') {
      final idx = m['index'];
      // Apply opponent move locally
      _gameProv.moveBlock(idx);
    } else if (type == 'status') {
      try {
        final time = m['time']?.toString() ?? '0.0';
        final steps = m['steps'] ?? 0;
        _socketProv.setOpponentStatus(time, steps);
      } catch (_) {}
    } else if (type == 'finish') {
      try {
        final oppTime = double.tryParse(m['time']?.toString() ?? '0.0') ?? 0.0;
        final oppSteps = m['steps'] ?? 0;
        _socketProv.setOpponentFinished(oppTime.toString(), oppSteps);
        // do NOT decide winner here for LAN; host will decide and broadcast 'result'
      } catch (_) {}
    } else if (type == 'result') {
      try {
        // result from host
        final winner = m['winner']; // 'host' or 'client'
        final wtime = m['winnerTime']?.toString() ?? '';
        final wsteps = m['winnerSteps'];
        // map to 'me'/'opponent' based on whether this device is host
        bool amHost = _localServerProv != null && _localServerProv!.isServerRunning;
        String winnerId;
        if (winner == 'host') {
          winnerId = amHost ? 'me' : 'opponent';
        } else {
          winnerId = amHost ? 'opponent' : 'me';
        }
        Map<String, dynamic> result = {'winnerId': winnerId, 'winnerTime': wtime, 'winnerSteps': wsteps};
        if (!_dialogShown) {
          _dialogShown = true;
          _showResultDialog(result);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _gameProv.removeListener(_syncStatus);
    _socketProv.removeListener(_socketListener);
    // unregister handled below for local providers
    if (_localClientProv != null) {
      _localClientProv!.unregisterMessageHandler(_onP2PMessage);
    }
    if (_localServerProv != null && _localServerMsgHandler != null) {
      _localServerProv!.unregisterMessageHandler(_localServerMsgHandler!);
    }
    super.dispose();
  }

  void _decideWinnerAsHostWithDelay() {
    // If opponent already finished, decide immediately; otherwise wait a short time then decide
    if (_socketProv.opponentFinished) {
      _decideWinnerAndBroadcast();
      return;
    }
    Timer(const Duration(milliseconds: 500), () {
      if (_socketProv.opponentFinished) {
        _decideWinnerAndBroadcast();
      } else {
        // opponent did not finish within timeout -> host wins
        _decideWinnerAndBroadcast();
      }
    });
  }

  void _decideWinnerAndBroadcast() {
    // Called on host to determine winner and broadcast 'result'
    double oppTime = double.tryParse(_socketProv.opponentData['time']?.toString() ?? '0.0') ?? double.infinity;
    int oppSteps = _socketProv.opponentData['steps'] ?? 0;
    double myTime = _localFinishTime ?? double.infinity;
    int mySteps = _localFinishSteps ?? 0;
    String winner = 'host';
    String winnerTime = myTime.toString();
    int winnerSteps = mySteps;
    if (oppTime < myTime) {
      winner = 'client';
      winnerTime = oppTime.toString();
      winnerSteps = oppSteps;
    }
    // broadcast result to clients
    try {
      _localServerProv?.sendToAll({'type': 'result', 'winner': winner, 'winnerTime': winnerTime, 'winnerSteps': winnerSteps});
    } catch (_) {}
    // show local dialog
    if (!_dialogShown) {
      _dialogShown = true;
      final res = {'winnerId': winner == 'host' ? 'me' : 'opponent', 'winnerTime': winnerTime, 'winnerSteps': winnerSteps};
      _showResultDialog(res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Selector<SocketProvider, int>(
          selector: (_, sp) => sp.gameSize,
          builder: (_, size, __) => Text('多人竞速 (${size}x$size)'),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmExit(),
            tooltip: '退出比赛',
          )
        ],
      ),
      body: Column(
        children: [
          _buildScoreBoard(),
          const Divider(height: 1),
          _buildPuzzleGrid(),
        ],
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出提示'),
        content: const Text('确定要退出当前比赛吗？这会导致比赛立即结束。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('继续游戏')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _socketProv.leaveRoom();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlphaValue(0.3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Local Stats - Only rebuilds on local game changes
          Selector<GameProvider, (String, int)>(
            selector: (_, gp) => (gp.timeString, gp.steps),
            builder: (context, data, _) =>
                _playerStats('你 (蓝色)', data.$1, data.$2, Colors.blue),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withAlphaValue(0.1),
            ),
            child: const Text(
              'VS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // Opponent Stats - Only rebuilds on socket updates
          Selector<SocketProvider, Map<String, dynamic>>(
            selector: (_, sp) => sp.opponentData,
            builder: (context, data, _) => _playerStats(
              '对手 (红色)',
              data['time']?.toString() ?? '0.0',
              data['steps'] ?? 0,
              Colors.red,
              status: data['status']?.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerStats(String name, String time, int steps, Color color, {String? status}) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$time s',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          '$steps 步',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        if (status != null && status.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(status, style: TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildPuzzleGrid() {
    return Expanded(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlphaValue(0.3),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                          color: Colors.black.withAlphaValue(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Consumer<GameProvider>(
                builder: (context, provider, _) {
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: provider.size,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: provider.layout.length,
                    itemBuilder: (context, index) {
                      int val = provider.layout[index];
                      if (val == 0) {
                        return SizedBox.shrink(key: ValueKey('empty'));
                      }
                      return GestureDetector(
                        key: ValueKey('block_$val'),
                        onTap: () {
                          final moved = provider.moveBlock(index);
                          if (moved) {
                            if (widget.useP2P) {
                              if (_localServerProv != null && _localServerProv!.isServerRunning) {
                                _localServerProv!.sendToAll({'type': 'move', 'index': index});
                              } else if (_localClientProv != null && _localClientProv!.isConnected) {
                                _localClientProv!.sendMessage({'type': 'move', 'index': index});
                              }
                            } else {
                              _socketProv.updateStatus(provider.timeString, provider.steps);
                            }
                          }
                        },
                        child: Consumer<GameProvider>(builder: (context, gp, _) {
                          if (gp.hasImage && gp.tileSrcRect(val) != null) {
                            final src = gp.tileSrcRect(val)!;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: _TileImagePainter(gp.image!, src),
                              ),
                            );
                          }
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade700,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$val',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showResultDialog(Map<String, dynamic> result) {
    bool win = false;
    final socketId = context.read<SocketProvider>().socket?.id;
    if (socketId != null) {
      win = result['winnerId'] == socketId;
    } else {
      // LAN mode: winnerId uses 'me' or 'opponent'
      win = result['winnerId'] == 'me';
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              win ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
              size: 64,
              color: win ? Colors.orange : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(win ? '🎉 获得胜利！' : '💀 惜败...'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '胜者用时: ${result['winnerTime']}s',
              style: const TextStyle(fontSize: 18),
            ),
            Text('胜者步数: ${result['winnerSteps']}步'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('回到首页'),
          ),
        ],
      ),
    );
  }
}
