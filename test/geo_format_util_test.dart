import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:moodiary/utils/geo_format_util.dart';

Placemark _pm({
  String? country,
  String? administrativeArea,
  String? locality,
  String? subLocality,
}) {
  return Placemark(
    name: '',
    street: '',
    isoCountryCode: '',
    country: country ?? '',
    postalCode: '',
    administrativeArea: administrativeArea ?? '',
    subAdministrativeArea: '',
    locality: locality ?? '',
    subLocality: subLocality ?? '',
    thoroughfare: '',
    subThoroughfare: '',
  );
}

void main() {
  group('formatCoords', () {
    test('positive lat/lng → N, E', () {
      expect(formatCoords(31.234, 121.473), '31.23°N, 121.47°E');
    });
    test('negative lat/lng → S, W', () {
      expect(formatCoords(-23.5, -46.6), '23.50°S, 46.60°W');
    });
    test('zero → 0.00°N, 0.00°E', () {
      expect(formatCoords(0, 0), '0.00°N, 0.00°E');
    });
  });

  group('composePlacemark (Asian locale)', () {
    const zh = Locale('zh');

    test('full fields → admin + locality + subLocality joined by space', () {
      final p = _pm(
        country: '中国',
        administrativeArea: '上海市',
        locality: '上海市',
        subLocality: '浦东新区',
      );
      expect(composePlacemark(p, zh), '上海市 上海市 浦东新区');
    });

    test('missing subLocality → admin + locality only', () {
      final p = _pm(
        country: '中国',
        administrativeArea: '北京市',
        locality: '北京市',
      );
      expect(composePlacemark(p, zh), '北京市 北京市');
    });

    test('only country → returns country', () {
      final p = _pm(country: '中国');
      expect(composePlacemark(p, zh), '中国');
    });

    test('all empty → null', () {
      final p = _pm();
      expect(composePlacemark(p, zh), null);
    });
  });

  group('composePlacemark (non-Asian locale)', () {
    const en = Locale('en');

    test('locality + country → "City, Country"', () {
      final p = _pm(
        country: 'China',
        administrativeArea: 'Shanghai',
        locality: 'Shanghai',
      );
      expect(composePlacemark(p, en), 'Shanghai, China');
    });

    test('only admin + country → "Admin, Country"', () {
      final p = _pm(country: 'China', administrativeArea: 'Shanghai');
      expect(composePlacemark(p, en), 'Shanghai, China');
    });

    test('only country → returns country', () {
      final p = _pm(country: 'China');
      expect(composePlacemark(p, en), 'China');
    });

    test('all empty → null', () {
      final p = _pm();
      expect(composePlacemark(p, en), null);
    });
  });

  test('null locale falls back to non-Asian rules', () {
    final p = _pm(country: 'China', locality: 'Shanghai');
    expect(composePlacemark(p, null), 'Shanghai, China');
  });
}
