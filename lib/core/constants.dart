class AppConstants {
  static const String appName = '数字华容道';
  
  // Hive Box Names
  static const String recordBox = 'game_records';
  static const String settingsBox = 'user_settings';
  
  // Settings Keys
  static const String keyDifficulty = 'default_difficulty';
  static const String keySoundEnabled = 'sound_enabled';
}

enum Difficulty {
  easy(3, '简单 (3x3)'),
  normal(4, '普通 (4x4)'),
  hard(5, '困难 (5x5)'),
  hell(6, '地狱 (6x6)');

  final int size;
  final String label;
  const Difficulty(this.size, this.label);
}
