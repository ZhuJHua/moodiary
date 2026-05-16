import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

String formatCoords(double lat, double lng) {
  final ns = lat >= 0 ? 'N' : 'S';
  final ew = lng >= 0 ? 'E' : 'W';
  return '${lat.abs().toStringAsFixed(2)}°$ns, '
      '${lng.abs().toStringAsFixed(2)}°$ew';
}

String? composePlacemark(Placemark p, Locale? locale) {
  bool ne(String? s) => s != null && s.isNotEmpty;

  final isAsian = locale != null &&
      const {'zh', 'ja', 'ko'}.contains(locale.languageCode);

  if (isAsian) {
    final parts = <String>[
      if (ne(p.administrativeArea)) p.administrativeArea!,
      if (ne(p.locality)) p.locality!,
      if (ne(p.subLocality)) p.subLocality!,
    ];
    if (parts.isNotEmpty) return parts.join(' ');
    return ne(p.country) ? p.country : null;
  }

  if (ne(p.locality) && ne(p.country)) return '${p.locality}, ${p.country}';
  if (ne(p.administrativeArea) && ne(p.country)) {
    return '${p.administrativeArea}, ${p.country}';
  }
  return ne(p.country) ? p.country : null;
}
