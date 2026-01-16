import 'package:hive/hive.dart';

part 'record.g.dart';

@HiveType(typeId: 0)
class GameRecord extends HiveObject {
  @HiveField(0)
  final int difficulty;

  @HiveField(1)
  final int timeInDeciseconds;

  @HiveField(2)
  final int steps;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final bool isMultiplayer; // 新增字段：区分单人/多人模式

  GameRecord({
    required this.difficulty,
    required this.timeInDeciseconds,
    required this.steps,
    required this.date,
    this.isMultiplayer = false,
  });

  String get timeString {
    double seconds = timeInDeciseconds / 10;
    return '${seconds.toStringAsFixed(1)}s';
  }
}
