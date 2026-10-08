import 'package:flutter_map/flutter_map.dart';
import 'package:mui/mui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_tile_source.dart';

const _tiandituAttribution = '天地图 GS (2026) 4921号';
const _osmAttribution = '© OpenStreetMap contributors';

const _tiandituVec =
    'https://t{s}.tianditu.gov.cn/vec_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=vec&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk={tk}';
const _tiandituCva =
    'https://t{s}.tianditu.gov.cn/cva_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cva&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk={tk}';
const _tiandituSubdomains = ['0', '1', '2', '3', '4', '5', '6', '7'];

const _userAgentPackageName = 'cn.yooss.moodiary';

List<Widget> mapTileLayers(
  MapTileSource source, {
  required String tiandituKey,
  required bool retina,
  ErrorTileCallBack? onError,
}) => switch (source) {
  .osm => [
    _OwnedTileLayer(
      key: const ValueKey(MapTileSource.osm),
      builder: (provider) => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        tileProvider: provider,
        userAgentPackageName: _userAgentPackageName,
        maxNativeZoom: 19,
        retinaMode: retina,
        errorTileCallback: onError,
      ),
    ),
  ],
  .tianditu => [
    for (final url in [_tiandituVec, _tiandituCva])
      _OwnedTileLayer(
        key: ValueKey(url),
        builder: (provider) => TileLayer(
          urlTemplate: url,
          tileProvider: provider,
          subdomains: _tiandituSubdomains,
          additionalOptions: {'tk': tiandituKey},
          userAgentPackageName: _userAgentPackageName,
          maxNativeZoom: 18,
          retinaMode: retina,
          errorTileCallback: onError,
        ),
      ),
  ],
};

class _OwnedTileLayer extends StatefulWidget {
  final TileLayer Function(TileProvider provider) builder;

  const _OwnedTileLayer({super.key, required this.builder});

  @override
  State<_OwnedTileLayer> createState() => _OwnedTileLayerState();
}

class _OwnedTileLayerState extends State<_OwnedTileLayer> {
  final _provider = NetworkTileProvider();

  @override
  Widget build(BuildContext context) => widget.builder(_provider);
}

class MapAttribution extends StatelessWidget {
  final MapTileSource source;

  const MapAttribution({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final (label, url) = switch (source) {
      .osm => (_osmAttribution, 'https://www.openstreetmap.org/copyright'),
      .tianditu => (_tiandituAttribution, 'https://www.tianditu.gov.cn/'),
    };
    return MOverlayLabel(
      label: label,
      onTap: () => launchUrl(Uri.parse(url), mode: .externalApplication),
    );
  }
}
