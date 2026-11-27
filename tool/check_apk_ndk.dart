import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Verifies F-Droid build invariants on compiled Moodiary Android APKs:
// - all source-built .so libs share the expected NDK (.note.android.ident)
// - libsqlite3.so matches SQLITE_SOURCE_ID from --sqlite-header
// - no Google Play DependencyInfoBlock (0x504B4453) in APK Signing Block
const _defaultLibs = [
  'libdartjni.so',
  'libsqlite3.so',
  'libsqlite3_vec.so',
  'libsqlite3_simple.so',
  'libfastcore.so',
  'libfastcrypto.so',
  'libfastimage.so',
  'libfastpress.so',
  'libfasttokenizer.so',
  'libfastzip.so',
];

const _apkSigBlockMagic = 'APK Sig Block 42';
const _dependencyInfoBlockId = 0x504B4453;

void main(List<String> args) {
  String? expectNdk;
  String? sqliteHeader;
  var wanted = _defaultLibs.toSet();
  final apks = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--expect' && i + 1 < args.length) {
      expectNdk = args[++i];
    } else if (arg.startsWith('--expect=')) {
      expectNdk = arg.substring('--expect='.length);
    } else if (arg == '--sqlite-header' && i + 1 < args.length) {
      sqliteHeader = args[++i];
    } else if (arg.startsWith('--sqlite-header=')) {
      sqliteHeader = arg.substring('--sqlite-header='.length);
    } else if (arg == '--libs' && i + 1 < args.length) {
      wanted = args[++i]
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    } else if (arg.startsWith('--libs=')) {
      wanted = arg
          .substring('--libs='.length)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    } else if (arg == '-h' || arg == '--help') {
      stdout.writeln(
        'Usage: dart tool/check_apk_ndk.dart [--expect <ndk>] '
        '[--sqlite-header <sqlite3.h>] [--libs <a.so,b.so>] <apk>...',
      );
      exit(0);
    } else if (arg.startsWith('-')) {
      _fail('Unknown option: $arg');
    } else {
      apks.add(arg);
    }
  }

  if (apks.isEmpty) {
    _fail('At least one APK path is required.');
  }

  final expectedBuild = expectNdk?.split('.').last;
  final expectedSqliteId = sqliteHeader == null
      ? null
      : utf8.encode(_readSqliteSourceId(sqliteHeader));

  final seen = <String, ({String release, String build})>{};
  var sqliteChecked = false;

  for (final apkPath in apks) {
    final file = File(apkPath);
    if (!file.existsSync()) {
      _fail('APK not found: $apkPath');
    }
    final bytes = file.readAsBytesSync();

    if (_hasDependencyInfoBlock(bytes)) {
      _fail(
        '$apkPath contains Google Play DependencyInfoBlock (0x504B4453). '
        'Set android.dependenciesInfo { includeInApk = false }.',
      );
    }

    final entries = _readZipEntries(bytes)
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final entry in entries) {
      if (!entry.name.startsWith('lib/')) continue;
      final libName = entry.name.split('/').last;
      if (!wanted.contains(libName)) continue;

      final elf = entry.readBytes();
      if (libName == 'libsqlite3.so' && expectedSqliteId != null) {
        if (!_containsBytes(elf, expectedSqliteId)) {
          _fail(
            '$apkPath!${entry.name} does not contain expected '
            'SQLITE_SOURCE_ID (${utf8.decode(expectedSqliteId)}) — '
            'was libsqlite3.so downloaded prebuilt?',
          );
        }
        sqliteChecked = true;
      }

      final ident = _readAndroidIdent(elf);
      if (ident == null) {
        _fail('$apkPath!${entry.name} is missing .note.android.ident');
      }
      seen['$apkPath!${entry.name}'] = ident;
    }
  }

  final foundNames = seen.keys.map((k) => k.split('/').last).toSet();
  final missing = wanted.difference(foundNames).toList()..sort();
  if (missing.isNotEmpty) {
    _fail('Not found in any APK: $missing');
  }

  for (final e in seen.entries) {
    final release = e.value.release.padLeft(8);
    final build = e.value.build.padLeft(10);
    stdout.writeln('$release $build  ${e.key}');
  }

  final builds = seen.values.map((v) => v.build).toSet();
  if (builds.length > 1) {
    final sorted = builds.toList()..sort();
    _fail('Source-built libraries came from multiple NDKs: $sorted');
  }
  if (expectedBuild != null && builds.single != expectedBuild) {
    _fail(
      'Source-built libraries used NDK build ${builds.single}, '
      'expected $expectNdk',
    );
  }
  if (expectedSqliteId != null && !sqliteChecked) {
    _fail('libsqlite3.so was not checked for SQLITE_SOURCE_ID');
  }

  stdout.writeln(
    'OK: verified ${seen.length} source-built native libraries'
    '${sqliteChecked ? ' (SQLITE_SOURCE_ID matched)' : ''}'
    ' and no Play DependencyInfoBlock.',
  );
}

Never _fail(String message) {
  stderr.writeln('::error::$message');
  exit(1);
}

String _readSqliteSourceId(String headerPath) {
  final text = File(headerPath).readAsStringSync();
  final match = RegExp(
    r'^#define\s+SQLITE_SOURCE_ID\s+"([^"]+)"',
    multiLine: true,
  ).firstMatch(text);
  if (match == null) {
    _fail('Could not find SQLITE_SOURCE_ID in $headerPath');
  }
  return match.group(1)!;
}

bool _containsBytes(Uint8List haystack, List<int> needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  final first = needle[0];
  final limit = haystack.length - needle.length;
  outer:
  for (var i = 0; i <= limit; i++) {
    if (haystack[i] != first) continue;
    for (var j = 1; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

int _findEocd(Uint8List bytes) {
  final minOffset = bytes.length > 65557 ? bytes.length - 65557 : 0;
  for (var i = bytes.length - 22; i >= minOffset; i--) {
    if (bytes[i] == 0x50 &&
        bytes[i + 1] == 0x4B &&
        bytes[i + 2] == 0x05 &&
        bytes[i + 3] == 0x06) {
      return i;
    }
  }
  return -1;
}

bool _hasDependencyInfoBlock(Uint8List bytes) {
  final eocd = _findEocd(bytes);
  if (eocd < 0) return false;
  final bd = ByteData.sublistView(bytes);
  final cdOffset = bd.getUint32(eocd + 16, Endian.little);
  if (cdOffset < 24) return false;

  final magic = ascii.decode(
    bytes.sublist(cdOffset - 16, cdOffset),
    allowInvalid: true,
  );
  if (magic != _apkSigBlockMagic) return false;

  final blockSize = bd.getUint64(cdOffset - 24, Endian.little);
  final blockStart = cdOffset - blockSize - 8;
  if (blockStart < 0) return false;
  final leadingSize = bd.getUint64(blockStart, Endian.little);
  if (leadingSize != blockSize) return false;

  var pos = blockStart + 8;
  final end = cdOffset - 24;
  while (pos + 12 <= end) {
    final pairLen = bd.getUint64(pos, Endian.little);
    pos += 8;
    if (pairLen < 4 || pos + pairLen > end) break;
    final pairId = bd.getUint32(pos, Endian.little);
    if (pairId == _dependencyInfoBlockId) return true;
    pos += pairLen;
  }
  return false;
}

final class _ZipEntry {
  final String name;
  final int method;
  final int compressedSize;
  final int localHeaderOffset;
  final Uint8List _archive;

  const _ZipEntry({
    required this.name,
    required this.method,
    required this.compressedSize,
    required this.localHeaderOffset,
    required Uint8List archive,
  }) : _archive = archive;

  Uint8List readBytes() {
    final bd = ByteData.sublistView(_archive);
    if (bd.getUint32(localHeaderOffset, Endian.little) != 0x04034B50) {
      _fail('Invalid ZIP local file header for $name');
    }
    final nameLen = bd.getUint16(localHeaderOffset + 26, Endian.little);
    final extraLen = bd.getUint16(localHeaderOffset + 28, Endian.little);
    final dataStart = localHeaderOffset + 30 + nameLen + extraLen;
    final raw = Uint8List.sublistView(
      _archive,
      dataStart,
      dataStart + compressedSize,
    );
    return switch (method) {
      0 => raw,
      8 => Uint8List.fromList(ZLibDecoder(raw: true).convert(raw)),
      _ => _fail('Unsupported ZIP compression method $method for $name'),
    };
  }
}

List<_ZipEntry> _readZipEntries(Uint8List bytes) {
  final eocd = _findEocd(bytes);
  if (eocd < 0) _fail('Not a valid ZIP/APK file (missing EOCD).');
  final bd = ByteData.sublistView(bytes);
  final cdSize = bd.getUint32(eocd + 12, Endian.little);
  final cdOffset = bd.getUint32(eocd + 16, Endian.little);

  final entries = <_ZipEntry>[];
  var pos = cdOffset;
  final end = cdOffset + cdSize;
  while (pos < end) {
    if (bd.getUint32(pos, Endian.little) != 0x02014B50) {
      _fail('Corrupt ZIP central directory at offset $pos');
    }
    final method = bd.getUint16(pos + 10, Endian.little);
    final compressedSize = bd.getUint32(pos + 20, Endian.little);
    final nameLen = bd.getUint16(pos + 28, Endian.little);
    final extraLen = bd.getUint16(pos + 30, Endian.little);
    final commentLen = bd.getUint16(pos + 32, Endian.little);
    final localOffset = bd.getUint32(pos + 42, Endian.little);
    final name = utf8.decode(bytes.sublist(pos + 46, pos + 46 + nameLen));
    entries.add(
      _ZipEntry(
        name: name,
        method: method,
        compressedSize: compressedSize,
        localHeaderOffset: localOffset,
        archive: bytes,
      ),
    );
    pos += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

({String release, String build})? _readAndroidIdent(Uint8List elf) {
  if (elf.length < 64 ||
      elf[0] != 0x7F ||
      elf[1] != 0x45 ||
      elf[2] != 0x4C ||
      elf[3] != 0x46) {
    return null;
  }
  final is64 = elf[4] == 2;
  final endian = elf[5] == 1 ? Endian.little : Endian.big;
  final bd = ByteData.sublistView(elf);

  final shoff = is64
      ? bd.getUint64(0x28, endian)
      : bd.getUint32(0x20, endian);
  final shentsize = bd.getUint16(is64 ? 0x3A : 0x2E, endian);
  final shnum = bd.getUint16(is64 ? 0x3C : 0x30, endian);
  final shstrndx = bd.getUint16(is64 ? 0x3E : 0x32, endian);

  ({int nameIdx, int offset, int size}) section(int idx) {
    final base = shoff + idx * shentsize;
    if (is64) {
      return (
        nameIdx: bd.getUint32(base, endian),
        offset: bd.getUint64(base + 24, endian),
        size: bd.getUint64(base + 32, endian),
      );
    }
    return (
      nameIdx: bd.getUint32(base, endian),
      offset: bd.getUint32(base + 16, endian),
      size: bd.getUint32(base + 20, endian),
    );
  }

  final strTab = section(shstrndx);
  String sectionName(int nameIdx) {
    final start = strTab.offset + nameIdx;
    var end = start;
    while (end < strTab.offset + strTab.size && elf[end] != 0) {
      end++;
    }
    return ascii.decode(elf.sublist(start, end), allowInvalid: true);
  }

  for (var i = 0; i < shnum; i++) {
    final sec = section(i);
    if (sectionName(sec.nameIdx) != '.note.android.ident') continue;
    final namesz = bd.getUint32(sec.offset, endian);
    final descsz = bd.getUint32(sec.offset + 4, endian);
    final descStart = sec.offset + 12 + ((namesz + 3) & ~3);
    if (descsz < 132 || descStart + 132 > elf.length) return null;
    return (
      release: _cString(elf, descStart + 4, 64),
      build: _cString(elf, descStart + 68, 64),
    );
  }
  return null;
}

String _cString(Uint8List bytes, int start, int maxLen) {
  var end = start;
  final limit = start + maxLen;
  while (end < limit && bytes[end] != 0) {
    end++;
  }
  return utf8.decode(bytes.sublist(start, end), allowMalformed: true);
}
