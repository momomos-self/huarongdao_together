import 'package:flutter/material.dart';
import '../utils/color_ext.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/permission_service.dart';
import 'dart:ui' as ui;
import '../core/constants.dart';
import '../provider/game_provider.dart';

class GamePage extends StatefulWidget {
  final Difficulty difficulty;
  final bool isImageMode;
  const GamePage({super.key, required this.difficulty, this.isImageMode = false});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.isImageMode) {
        // Prompt for initial image; if none selected, fall back to numeric mode start
        final granted = await PermissionService.requestPhotoPermissions(context);
        if (!mounted) return;
        if (granted) {
          final picker = ImagePicker();
          final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
          if (!mounted) return;
          if (file != null) {
            final bytes = await file.readAsBytes();
            await context.read<GameProvider>().setImageBytes(bytes);
          }
        }
      }
      if (!mounted) return;
      context.read<GameProvider>().startGame(widget.difficulty.size);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.difficulty.label),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo),
            onPressed: () async {
              final granted = await PermissionService.requestPhotoPermissions(context);
              if (!granted) return;
              final picker = ImagePicker();
              final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
              if (file != null) {
                final bytes = await file.readAsBytes();
                await context.read<GameProvider>().setImageBytes(bytes);
                // restart game to apply image tiles
                context.read<GameProvider>().startGame(widget.difficulty.size);
              }
            },
            tooltip: '选择图片作为拼图',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<GameProvider>().startGame(widget.difficulty.size),
          )
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildHeader(provider),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlphaValue(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: provider.size,
                          mainAxisSpacing: provider.hasImage ? 2 : 8,
                          crossAxisSpacing: provider.hasImage ? 2 : 8,
                        ),
                        itemCount: provider.layout.length,
                        itemBuilder: (context, index) {
                          int val = provider.layout[index];
                          if (val == 0) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: () => provider.moveBlock(index),
                            child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withAlphaValue(0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Consumer<GameProvider>(builder: (context, gp, _) {
                                    if (gp.hasImage && gp.tileSrcRect(val) != null) {
                                      final src = gp.tileSrcRect(val)!;
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(gp.hasImage ? 6 : 12),
                                        child: CustomPaint(
                                          size: Size.infinite,
                                          painter: _TileImagePainter(gp.image!, src),
                                        ),
                                      );
                                    }
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.blue.shade400, Colors.blue.shade700],
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
                                ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              _buildFooter(context, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(GameProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _infoCard('步数', '${provider.steps}', Icons.format_list_numbered),
          _infoCard('用时', '${provider.timeString}s', Icons.timer_outlined),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, GameProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 50),
      child: provider.isGameOver
          ? Column(
              children: [
                const Text('🎉 挑战成功！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('返回首页'),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

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
