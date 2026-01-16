import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../models/record.dart';
import '../utils/puzzle_utils.dart';
import '../core/constants.dart';
import 'package:hive/hive.dart';

class GameProvider with ChangeNotifier {
  int _size = 3;
  List<int> _layout = [];
  int _steps = 0;
  int _deciseconds = 0;
  Timer? _timer;
  bool _isGameOver = false;
  bool _isPaused = false;

  bool _isMultiplayer = false;
  Uint8List? _imageBytes;
  ui.Image? _image;
  bool get hasImage => _image != null;
  ui.Image? get image => _image;
  Uint8List? get imageBytes => _imageBytes;

  int get size => _size;
  List<int> get layout => _layout;
  int get steps => _steps;
  int get deciseconds => _deciseconds;
  bool get isGameOver => _isGameOver;
  bool get isPaused => _isPaused;

  String get timeString {
    double sec = _deciseconds / 10;
    return sec.toStringAsFixed(1);
  }

  void startGame(int size, {List<int>? initialLayout, bool isMultiplayer = false}) {
    _size = size;
    _layout = initialLayout ?? PuzzleUtils.generateSolvableLayout(size);
    _steps = 0;
    _deciseconds = 0;
    _isGameOver = false;
    _isPaused = false;
    _isMultiplayer = isMultiplayer;
    _startTimer();
    notifyListeners();
  }

  Future<void> setImageBytes(Uint8List bytes) async {
    _imageBytes = bytes;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _image = frame.image;
    } catch (_) {
      _image = null;
    }
    notifyListeners();
  }

  void clearImage() {
    _imageBytes = null;
    _image = null;
    notifyListeners();
  }

  // Returns source rect within the image for a tile value (1-based value)
  ui.Rect? tileSrcRect(int value) {
    if (_image == null) return null;
    if (value == 0) return null;
    final int idx = value - 1; // goal position index
    final int row = idx ~/ _size;
    final int col = idx % _size;
    final double tileW = _image!.width / _size;
    final double tileH = _image!.height / _size;
    return ui.Rect.fromLTWH(col * tileW, row * tileH, tileW, tileH);
  }

  void stopGame() {
    _timer?.cancel();
    _isGameOver = true;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isPaused && !_isGameOver) {
        _deciseconds++;
        notifyListeners();
      }
    });
  }

  void togglePause() {
    _isPaused = !_isPaused;
    notifyListeners();
  }

  bool moveBlock(int index) {
    if (_isGameOver || _isPaused) return false;
    
    int blankIndex = _layout.indexOf(0);
    if (_isAdjacent(index, blankIndex)) {
      _layout[blankIndex] = _layout[index];
      _layout[index] = 0;
      _steps++;
      
      if (PuzzleUtils.isSolved(_layout)) {
        _isGameOver = true;
        _timer?.cancel();
        _saveRecord();
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  bool _isAdjacent(int idx1, int idx2) {
    int row1 = idx1 ~/ _size;
    int col1 = idx1 % _size;
    int row2 = idx2 ~/ _size;
    int col2 = idx2 % _size;
    return (row1 == row2 && (col1 - col2).abs() == 1) ||
           (col1 == col2 && (row1 - row2).abs() == 1);
  }

  Future<void> _saveRecord() async {
    final box = Hive.box<GameRecord>(AppConstants.recordBox);
    final newRecord = GameRecord(
      difficulty: _size,
      timeInDeciseconds: _deciseconds,
      steps: _steps,
      date: DateTime.now(),
      isMultiplayer: _isMultiplayer,
    );
    await box.add(newRecord);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
