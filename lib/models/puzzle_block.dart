class PuzzleBlock {
  final int value; // 0 represents the empty space
  int currentPos;

  PuzzleBlock({required this.value, required this.currentPos});

  bool get isEmpty => value == 0;
}
