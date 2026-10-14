abstract final class EditDistance {
  static int levenshtein(String source, String target) {
    if (source == target) return 0;
    if (source.isEmpty) return target.length;
    if (target.isEmpty) return source.length;
    var previous = List<int>.generate(target.length + 1, (index) => index);
    for (var sourceIndex = 0; sourceIndex < source.length; sourceIndex++) {
      final current = List<int>.filled(target.length + 1, 0);
      current[0] = sourceIndex + 1;
      for (var targetIndex = 0; targetIndex < target.length; targetIndex++) {
        final substitutionCost =
            source.codeUnitAt(sourceIndex) == target.codeUnitAt(targetIndex)
            ? 0
            : 1;
        current[targetIndex + 1] = _minimum(
          current[targetIndex] + 1,
          previous[targetIndex + 1] + 1,
          previous[targetIndex] + substitutionCost,
        );
      }
      previous = current;
    }
    return previous.last;
  }

  static double similarity(String source, String target) {
    final maximum = source.length > target.length
        ? source.length
        : target.length;
    if (maximum == 0) return 1;
    return 1 - (levenshtein(source, target) / maximum);
  }

  static int _minimum(int first, int second, int third) {
    var value = first < second ? first : second;
    if (third < value) value = third;
    return value;
  }
}
