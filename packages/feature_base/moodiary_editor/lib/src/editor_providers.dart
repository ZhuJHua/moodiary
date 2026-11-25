import 'package:moodiary_http/moodiary_http.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data/geo_repository.dart';
import 'data/weather_repository.dart';

part 'editor_providers.g.dart';

@Riverpod(keepAlive: true)
GeoRepository geoRepository(Ref ref) =>
    GeoRepository(ref.watch(httpClientProvider));

@Riverpod(keepAlive: true)
WeatherRepository weatherRepository(Ref ref) =>
    WeatherRepository(ref.watch(httpClientProvider));
