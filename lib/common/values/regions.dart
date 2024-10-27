import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

class ChinaRegions {
  // 定义中国所有省份的瓦片区域
  static final regions = {
    'Beijing': RectangleRegion(
      LatLngBounds(const LatLng(39.4427, 115.4213), const LatLng(41.0599, 117.5143)),
    ),
    'Tianjin': RectangleRegion(
      LatLngBounds(const LatLng(38.5547, 116.7257), const LatLng(40.2555, 118.0481)),
    ),
    'Hebei': RectangleRegion(
      LatLngBounds(const LatLng(36.0513, 113.4620), const LatLng(42.6502, 119.8485)),
    ),
    'Shanxi': RectangleRegion(
      LatLngBounds(const LatLng(34.4824, 110.1619), const LatLng(40.9982, 114.7482)),
    ),
    'Inner Mongolia': RectangleRegion(
      LatLngBounds(const LatLng(37.4229, 97.1681), const LatLng(53.3318, 126.0386)),
    ),
    'Liaoning': RectangleRegion(
      LatLngBounds(const LatLng(38.7216, 118.9151), const LatLng(43.4845, 125.5690)),
    ),
    'Jilin': RectangleRegion(
      LatLngBounds(const LatLng(40.8624, 121.3644), const LatLng(46.6387, 131.2433)),
    ),
    'Heilongjiang': RectangleRegion(
      LatLngBounds(const LatLng(43.4329, 121.1836), const LatLng(53.5581, 135.0865)),
    ),
    'Shanghai': RectangleRegion(
      LatLngBounds(const LatLng(30.6647, 120.8526), const LatLng(31.8832, 122.1084)),
    ),
    'Jiangsu': RectangleRegion(
      LatLngBounds(const LatLng(30.4505, 116.8286), const LatLng(35.1224, 121.1320)),
    ),
    'Zhejiang': RectangleRegion(
      LatLngBounds(const LatLng(27.1934, 118.0219), const LatLng(31.0895, 122.2274)),
    ),
    'Anhui': RectangleRegion(
      LatLngBounds(const LatLng(29.4119, 114.8926), const LatLng(34.6568, 119.6455)),
    ),
    'Fujian': RectangleRegion(
      LatLngBounds(const LatLng(23.5636, 116.7407), const LatLng(28.4387, 120.8369)),
    ),
    'Jiangxi': RectangleRegion(
      LatLngBounds(const LatLng(24.4124, 113.5877), const LatLng(30.0756, 118.6083)),
    ),
    'Shandong': RectangleRegion(
      LatLngBounds(const LatLng(34.3944, 114.8054), const LatLng(38.3072, 122.6978)),
    ),
    'Henan': RectangleRegion(
      LatLngBounds(const LatLng(31.3802, 110.3787), const LatLng(36.5819, 116.6942)),
    ),
    'Hubei': RectangleRegion(
      LatLngBounds(const LatLng(29.0470, 108.4110), const LatLng(33.4238, 116.0797)),
    ),
    'Hunan': RectangleRegion(
      LatLngBounds(const LatLng(24.6366, 108.7877), const LatLng(30.1238, 114.2341)),
    ),
    'Guangdong': RectangleRegion(
      LatLngBounds(const LatLng(20.0268, 109.6642), const LatLng(25.5186, 117.2037)),
    ),
    'Guangxi': RectangleRegion(
      LatLngBounds(const LatLng(20.5400, 104.4759), const LatLng(26.2504, 112.0472)),
    ),
    'Hainan': RectangleRegion(
      LatLngBounds(const LatLng(18.1460, 108.5117), const LatLng(20.2706, 111.0257)),
    ),
    'Chongqing': RectangleRegion(
      LatLngBounds(const LatLng(28.1124, 105.2875), const LatLng(32.1310, 110.4740)),
    ),
    'Sichuan': RectangleRegion(
      LatLngBounds(const LatLng(26.0490, 97.3516), const LatLng(34.3143, 108.5740)),
    ),
    'Guizhou': RectangleRegion(
      LatLngBounds(const LatLng(24.3965, 103.5901), const LatLng(29.2275, 109.2114)),
    ),
    'Yunnan': RectangleRegion(
      LatLngBounds(const LatLng(21.1375, 97.6400), const LatLng(29.2227, 106.1124)),
    ),
    'Tibet': RectangleRegion(
      LatLngBounds(const LatLng(26.0000, 78.3949), const LatLng(36.4538, 99.1089)),
    ),
    'Shaanxi': RectangleRegion(
      LatLngBounds(const LatLng(31.7024, 105.4964), const LatLng(39.5957, 111.2605)),
    ),
    'Gansu': RectangleRegion(
      LatLngBounds(const LatLng(32.1043, 92.1316), const LatLng(42.7932, 108.7309)),
    ),
    'Qinghai': RectangleRegion(
      LatLngBounds(const LatLng(31.5875, 89.6198), const LatLng(39.7931, 101.8822)),
    ),
    'Ningxia': RectangleRegion(
      LatLngBounds(const LatLng(35.3135, 104.1455), const LatLng(39.3749, 107.9047)),
    ),
    'Xinjiang': RectangleRegion(
      LatLngBounds(const LatLng(34.2231, 73.4994), const LatLng(49.1720, 96.3877)),
    ),
    'Hong Kong': RectangleRegion(
      LatLngBounds(const LatLng(22.1193, 113.8252), const LatLng(22.5645, 114.4462)),
    ),
    'Macau': RectangleRegion(
      LatLngBounds(const LatLng(22.1092, 113.5286), const LatLng(22.2176, 113.6069)),
    ),
    'Taiwan': RectangleRegion(
      LatLngBounds(const LatLng(20.5170, 119.4189), const LatLng(25.4152, 122.0184)),
    ),
  };
}
