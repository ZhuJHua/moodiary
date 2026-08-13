import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

void main() {
  test('uses explicit color when set', () {
    expect(
      categoryColorOf(colorValue: 0xFF42A5F5, id: 'x'),
      const Color(0xFF42A5F5),
    );
  });

  test('derives a stable palette color when unset', () {
    final a = categoryColorOf(colorValue: null, id: 'cat-123');
    final b = categoryColorOf(colorValue: null, id: 'cat-123');
    expect(a, b);
    expect(kCategoryPalette.contains(a), isTrue);
  });
}
