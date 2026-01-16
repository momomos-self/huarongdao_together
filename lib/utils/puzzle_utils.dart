import 'dart:math';

class PuzzleUtils {
  /// Generates a solvable puzzle by starting from the goal state 
  /// and performing random valid moves.
  static List<int> generateSolvableLayout(int size) {
    int total = size * size;
    // Goal state: [1, 2, ..., 0]
    List<int> layout = List.generate(total, (index) => (index + 1) % total);
    
    int blankIndex = total - 1;
    Random random = Random();
    
    // Performance: Shuffle enough times
    int moves = size * size * size * 10; 
    for (int i = 0; i < moves; i++) {
      List<int> neighbors = _getNeighbors(blankIndex, size);
      int targetIndex = neighbors[random.nextInt(neighbors.length)];
      
      _swap(layout, blankIndex, targetIndex);
      blankIndex = targetIndex;
    }

    // Requirement: Ensure blank (0) is at the FIRST grid (index 0) at the start
    // We move the blank to [0, 0] using a simple path to maintain solvability
    while (blankIndex != 0) {
      int bRow = blankIndex ~/ size;
      int bCol = blankIndex % size;
      
      int targetIndex;
      if (bCol > 0) {
        targetIndex = blankIndex - 1; // Move Left
      } else if (bRow > 0) {
        targetIndex = blankIndex - size; // Move Up
      } else {
        break; // Should not happen given the conditions
      }
      
      _swap(layout, blankIndex, targetIndex);
      blankIndex = targetIndex;
    }
    
    return layout;
  }

  static void _swap(List<int> list, int i, int j) {
    int temp = list[i];
    list[i] = list[j];
    list[j] = temp;
  }

  static List<int> _getNeighbors(int index, int size) {
    List<int> neighbors = [];
    int row = index ~/ size;
    int col = index % size;

    if (row > 0) neighbors.add(index - size); // Up
    if (row < size - 1) neighbors.add(index + size); // Down
    if (col > 0) neighbors.add(index - 1); // Left
    if (col < size - 1) neighbors.add(index + 1); // Right
    
    return neighbors;
  }

  static bool isSolved(List<int> layout) {
    int total = layout.length;
    // 检查前 total - 1 个位置是否依次为 1, 2, 3...
    for (int i = 0; i < total - 1; i++) {
      if (layout[i] != i + 1) return false;
    }
    // 检查最后一个位置是否为 0（空白块）
    return layout[total - 1] == 0;
  }
}
