import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mobile/app/settings/storage/storage_bar.dart';

void main() {
  double sum(List<double> w) => w.fold(0.0, (a, b) => a + b);

  test('tiny categories get the minimum width, the rest keep their ratio', () {
    final w = storageSegmentWidths([1000, 1, 0, 500, 0.5], 300);
    expect(sum(w), closeTo(300, 1e-9));
    expect(w[1], 8);
    expect(w[4], 8);
    expect(w[2], 0);
    expect(w[0] / w[3], closeTo(2, 1e-9));
  });

  test('proportional widths are untouched when everything is wide enough', () {
    final w = storageSegmentWidths([1, 1, 2], 400);
    expect(w, [100, 100, 200]);
  });

  test('splits evenly when the minimums do not fit', () {
    final w = storageSegmentWidths([100, 1, 1], 20);
    expect(w, [for (var i = 0; i < 3; i++) closeTo(20 / 3, 1e-9)]);
  });

  test('empty bar stays empty', () {
    expect(storageSegmentWidths([0, 0], 300), [0, 0]);
    expect(storageSegmentWidths([5], 0), [0]);
  });
}
