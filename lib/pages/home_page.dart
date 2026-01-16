import 'package:flutter/material.dart';
// imports for image picking and provider are not required here; GamePage handles image selection
import '../utils/color_ext.dart';
import '../core/constants.dart';
import 'game_page.dart';
import 'room_page.dart';
import 'record_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade100, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grid_4x4_rounded, size: 80, color: Colors.blue),
                const SizedBox(height: 10),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 50),
                _buildMenuButton(context, '单人挑战', Icons.person_outline, Colors.blue, 
                    () => _selectDifficulty(context)),
                const SizedBox(height: 20),
                _buildMenuButton(context, '联机竞速', Icons.people_outline, Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomPage()));
                }),
                const SizedBox(height: 20),
                _buildMenuButton(context, '排行榜', Icons.leaderboard_outlined, Colors.green, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordPage()));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String text, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: 250,
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          elevation: 4,
          shadowColor: color.withAlphaValue(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: color.withAlphaValue(0.5), width: 1),
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _selectDifficulty(BuildContext context) async {
    // First ask user to choose mode: 图片模式 or 数字模式
    final isImage = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择模式', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('数字模式'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('图片模式'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isImage == null) return;

    // Then choose difficulty
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择挑战难度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              ...Difficulty.values.map((d) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Text('${d.size}x', style: const TextStyle(color: Colors.blue)),
                ),
                title: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () async {
                  Navigator.pop(context);
                  // If image mode, GamePage will handle initial image selection.
                  Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(difficulty: d, isImageMode: isImage)));
                },
              )),
              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }
}
