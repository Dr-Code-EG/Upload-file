import 'package:flutter/foundation.dart';

@immutable
class DominoTile {
  final int left;
  final int right;

  const DominoTile(this.left, this.right);

  bool get isDouble => left == right;
  int get pips => left + right;

  bool hasValue(int v) => left == v || right == v;

  /// Returns the other end if [v] matches one side, else null.
  int? other(int v) {
    if (left == v) return right;
    if (right == v) return left;
    return null;
  }

  /// Canonical key (smaller first) so 3|5 and 5|3 are equal.
  String get key {
    final a = left < right ? left : right;
    final b = left < right ? right : left;
    return '$a-$b';
  }

  DominoTile flipped() => DominoTile(right, left);

  @override
  bool operator ==(Object other) =>
      other is DominoTile && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => '[$left|$right]';

  /// Generate a full double-six set (28 tiles).
  static List<DominoTile> standardSet() {
    final tiles = <DominoTile>[];
    for (var i = 0; i <= 6; i++) {
      for (var j = i; j <= 6; j++) {
        tiles.add(DominoTile(i, j));
      }
    }
    return tiles;
  }
}
