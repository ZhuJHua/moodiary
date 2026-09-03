import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 直接读 SFNT 表：`name`（全名）与 `fvar`（可变字体 wght 轴）。
///
/// TTF / OTF（CFF）/ TTC（取第 0 张脸）都认。与曾经的 Rust ttf-parser 实现逐字对比过
/// （Dosis、Apple 的多轴 SF、Songti.ttc、Noto OTF），行为一致：没有 Unicode 名字记录返回 null，
/// 没有 fvar 返回空表。
abstract final class FontTables {
  /// nameID 4（Full font name）的 Unicode 记录；只有 Mac Roman 记录的老字体拿不到。
  static Future<String?> fullName(String path) async {
    final d = ByteData.sublistView(await File(path).readAsBytes());
    final tables = _tables(d);
    final name = tables['name'];
    if (name == null) return null;
    return _names(d, name)[4];
  }

  /// `{"default": 轴默认值, "<命名实例>": 该实例的 wght}`；没有 fvar 或没有 wght 轴则为空。
  static Future<Map<String, double>> wghtAxis(String path) async {
    final d = ByteData.sublistView(await File(path).readAsBytes());
    final tables = _tables(d);
    final fvar = tables['fvar'], name = tables['name'];
    if (fvar == null || name == null) return const {};
    return _wght(d, fvar, _names(d, name));
  }
}

const _ttcTag = 0x74746366; // 'ttcf'

/// 表目录：tag → (offset, length)。
Map<String, (int, int)> _tables(ByteData d) {
  var base = 0;
  if (d.getUint32(0) == _ttcTag) base = d.getUint32(12); // 第 0 张脸的偏移
  final numTables = d.getUint16(base + 4);
  final out = <String, (int, int)>{};
  for (var i = 0; i < numTables; i++) {
    final r = base + 12 + i * 16;
    final tag = ascii.decode(d.buffer.asUint8List(d.offsetInBytes + r, 4));
    out[tag] = (d.getUint32(r + 8), d.getUint32(r + 12));
  }
  return out;
}

/// name 表：每个 nameID 取第一条 Unicode 记录（platform 0，或 platform 3 且 encoding 0/1/10），
/// UTF-16BE 解码。
Map<int, String> _names(ByteData d, (int, int) table) {
  final (off, _) = table;
  final count = d.getUint16(off + 2), strOff = off + d.getUint16(off + 4);
  final out = <int, String>{};
  for (var i = 0; i < count; i++) {
    final r = off + 6 + i * 12;
    final platform = d.getUint16(r), encoding = d.getUint16(r + 2);
    final nameId = d.getUint16(r + 6);
    final len = d.getUint16(r + 8), so = d.getUint16(r + 10);
    final unicode =
        platform == 0 ||
        (platform == 3 && (encoding == 0 || encoding == 1 || encoding == 10));
    if (!unicode || out.containsKey(nameId)) continue;
    final b = d.buffer.asUint8List(d.offsetInBytes + strOff + so, len);
    out[nameId] = String.fromCharCodes([
      for (var j = 0; j + 1 < len; j += 2) (b[j] << 8) | b[j + 1],
    ]);
  }
  return out;
}

double _fixed(ByteData d, int o) => d.getInt32(o) / 65536.0;

/// fvar 表：wght 轴默认值 + 每个命名实例的 wght。
Map<String, double> _wght(
  ByteData d,
  (int, int) table,
  Map<int, String> names,
) {
  final (off, _) = table;
  final axesOff = off + d.getUint16(off + 4);
  final axisCount = d.getUint16(off + 8), axisSize = d.getUint16(off + 10);
  final instCount = d.getUint16(off + 12), instSize = d.getUint16(off + 14);
  var wghtIndex = -1;
  final out = <String, double>{};
  for (var i = 0; i < axisCount; i++) {
    final a = axesOff + i * axisSize;
    if (ascii.decode(d.buffer.asUint8List(d.offsetInBytes + a, 4)) == 'wght') {
      wghtIndex = i;
      out['default'] = _fixed(d, a + 8);
    }
  }
  if (wghtIndex < 0) return const {};
  final instOff = axesOff + axisCount * axisSize;
  for (var i = 0; i < instCount; i++) {
    final r = instOff + i * instSize;
    final subfamily = names[d.getUint16(r)];
    if (subfamily == null) continue;
    out[subfamily] = _fixed(d, r + 4 + wghtIndex * 4);
  }
  return out;
}
