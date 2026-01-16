import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/color_ext.dart';
import '../models/record.dart';
import '../core/constants.dart';

class RecordPage extends StatelessWidget {
  const RecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('战绩与荣誉'), centerTitle: true),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<GameRecord>(AppConstants.recordBox).listenable(),
        builder: (context, Box<GameRecord> box, _) {
          if (box.isEmpty) {
            return _buildEmptyState();
          }

          final allRecords = box.values.toList();
          // 全部记录按日期倒序
          final recentRecords = List<GameRecord>.from(allRecords)..sort((a, b) => b.date.compareTo(a.date));

          return CustomScrollView(
            slivers: [
              // 1. 巅峰统计标题
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text('巅峰统计 (各项目最佳)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              // 2. 巅峰统计横向列表
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    children: Difficulty.values.map((d) => _buildBestCard(allRecords, d)).toList(),
                  ),
                ),
              ),
              // 3. 历史记录标题
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
                  child: Text('最近战绩', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              // 4. 全部记录列表
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final r = recentRecords[index];
                      return _buildRecentItem(r);
                    },
                    childCount: recentRecords.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text('暂无战绩，期待你的首次挑战！', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBestCard(List<GameRecord> all, Difficulty d) {
    final difRecords = all.where((r) => r.difficulty == d.size).toList();
    if (difRecords.isEmpty) {
      return Container(
        width: 180,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(d.label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            const Text('暂无数据', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    // 最佳时间
    final bestTimeRec = difRecords.reduce((a, b) => a.timeInDeciseconds < b.timeInDeciseconds ? a : b);
    // 最佳步数
    final bestStepRec = difRecords.reduce((a, b) => a.steps < b.steps ? a : b);

    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withAlphaValue(0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(d.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(Icons.stars, color: Colors.amber, size: 20),
            ],
          ),
          const Spacer(),
          _statRow(Icons.timer, '最佳时间', '${bestTimeRec.timeString} (${bestTimeRec.steps}步)'),
          const SizedBox(height: 8),
          _statRow(Icons.directions_run, '最少步数', '${bestStepRec.steps}步 (${bestStepRec.timeString})'),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.blue.shade100),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.blue.shade50, fontSize: 10)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentItem(GameRecord r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withAlphaValue(0.02), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: r.isMultiplayer ? Colors.orange.shade50 : Colors.blue.shade50,
          child: Text(
            '${r.difficulty}x', 
            style: TextStyle(color: r.isMultiplayer ? Colors.orange : Colors.blue, fontWeight: FontWeight.bold)
          ),
        ),
        title: Row(
          children: [
            Text('用时 ${r.timeString}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (r.isMultiplayer) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('联机', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: Text('${r.steps} 步 | ${r.date.toString().substring(0, 16)}'),
      ),
    );
  }
}
