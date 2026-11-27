import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Fetches the official SQLite amalgamation from sqlite.org, verifies its
// SHA3-256 against download.html, and unpacks sqlite3.c / sqlite3.h into
// third_party/sqlite3/.
//
// Usage: fvm dart tool/update_sqlite.dart [--force] [<version>]
const _destDir = 'third_party/sqlite3';
const _downloadPage = 'https://sqlite.org/download.html';

Future<void> main(List<String> args) async {
  String? wantVersion;
  var force = false;
  for (final arg in args) {
    if (arg == '--force') {
      force = true;
    } else if (arg == '-h' || arg == '--help') {
      stdout.writeln(
        'Usage: fvm dart tool/update_sqlite.dart [--force] [<version>]',
      );
      exit(0);
    } else if (arg.startsWith('-')) {
      _fail('Unknown option: $arg');
    } else if (wantVersion == null) {
      wantVersion = arg;
    } else {
      _fail('Unexpected argument: $arg');
    }
  }

  final client = HttpClient()..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    final page = utf8.decode(await _getBytes(client, Uri.parse(_downloadPage)));
    final match = RegExp(
      r'PRODUCT,([0-9.]+),([0-9]+/sqlite-amalgamation-[0-9]+\.zip),[0-9]+,([0-9a-f]{64})',
    ).firstMatch(page);
    if (match == null) _fail('No amalgamation found on $_downloadPage');

    final version = match.group(1)!;
    final relPath = match.group(2)!;
    final expectedSha3 = match.group(3)!;

    if (wantVersion != null && wantVersion != version) {
      _fail('sqlite.org offers $version, not $wantVersion');
    }

    final headerFile = File('$_destDir/sqlite3.h');
    var current = 'none';
    if (headerFile.existsSync()) {
      final m = RegExp(
        r'^#define\s+SQLITE_VERSION\s+"([0-9.]+)"',
        multiLine: true,
      ).firstMatch(headerFile.readAsStringSync());
      if (m != null) current = m.group(1)!;
      if (!force && current == version) {
        stdout.writeln('Already at SQLite $version.');
        return;
      }
    }

    final url = Uri.parse('https://sqlite.org/$relPath');
    stdout.writeln('Downloading $url ...');
    final archiveBytes = await _getBytes(client, url);

    final actualSha3 = _hex(_sha3_256(archiveBytes));
    if (actualSha3 != expectedSha3) {
      _fail(
        'SHA3-256 mismatch for $url\n'
        '  expected $expectedSha3\n'
        '  got      $actualSha3',
      );
    }

    final files = _extractZipFiles(archiveBytes, const {
      'sqlite3.c',
      'sqlite3.h',
    });
    final sqliteC = files['sqlite3.c'];
    final sqliteH = files['sqlite3.h'];
    if (sqliteC == null || sqliteH == null) {
      _fail('Archive $url is missing sqlite3.c or sqlite3.h');
    }

    Directory(_destDir).createSync(recursive: true);
    File('$_destDir/sqlite3.c').writeAsBytesSync(sqliteC);
    File('$_destDir/sqlite3.h').writeAsBytesSync(sqliteH);

    stdout.writeln(
      'SQLite $current -> $version (SHA3-256 verified). '
      'Run `fvm dart tool/task.dart test --all` before committing.',
    );
  } finally {
    client.close();
  }
}

Never _fail(String message) {
  stderr.writeln('✗ $message');
  exit(1);
}

Future<Uint8List> _getBytes(HttpClient client, Uri uri) async {
  final req = await client.getUrl(uri);
  final res = await req.close();
  if (res.statusCode != HttpStatus.ok) {
    _fail('HTTP ${res.statusCode} fetching $uri');
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in res) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Map<String, Uint8List> _extractZipFiles(Uint8List bytes, Set<String> wanted) {
  final minOffset = bytes.length > 65557 ? bytes.length - 65557 : 0;
  var eocd = -1;
  for (var i = bytes.length - 22; i >= minOffset; i--) {
    if (bytes[i] == 0x50 &&
        bytes[i + 1] == 0x4B &&
        bytes[i + 2] == 0x05 &&
        bytes[i + 3] == 0x06) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) _fail('Invalid ZIP archive (missing EOCD)');

  final bd = ByteData.sublistView(bytes);
  final cdSize = bd.getUint32(eocd + 12, Endian.little);
  final cdOffset = bd.getUint32(eocd + 16, Endian.little);

  final out = <String, Uint8List>{};
  var pos = cdOffset;
  final end = cdOffset + cdSize;
  while (pos < end) {
    if (bd.getUint32(pos, Endian.little) != 0x02014B50) {
      _fail('Corrupt ZIP central directory at offset $pos');
    }
    final method = bd.getUint16(pos + 10, Endian.little);
    final compSize = bd.getUint32(pos + 20, Endian.little);
    final nameLen = bd.getUint16(pos + 28, Endian.little);
    final extraLen = bd.getUint16(pos + 30, Endian.little);
    final commentLen = bd.getUint16(pos + 32, Endian.little);
    final localOffset = bd.getUint32(pos + 42, Endian.little);
    final fullName = utf8.decode(bytes.sublist(pos + 46, pos + 46 + nameLen));
    final baseName = fullName.split('/').last;
    pos += 46 + nameLen + extraLen + commentLen;

    if (!wanted.contains(baseName)) continue;
    if (bd.getUint32(localOffset, Endian.little) != 0x04034B50) {
      _fail('Invalid ZIP local file header for $fullName');
    }
    final lNameLen = bd.getUint16(localOffset + 26, Endian.little);
    final lExtraLen = bd.getUint16(localOffset + 28, Endian.little);
    final dataStart = localOffset + 30 + lNameLen + lExtraLen;
    final raw = Uint8List.sublistView(bytes, dataStart, dataStart + compSize);
    out[baseName] = switch (method) {
      0 => Uint8List.fromList(raw),
      8 => Uint8List.fromList(ZLibDecoder(raw: true).convert(raw)),
      _ => _fail('Unsupported ZIP method $method for $fullName'),
    };
  }
  return out;
}

String _hex(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

const _keccakRc = [
  0x0000000000000001, 0x0000000000008082, 0x800000000000808A,
  0x8000000080008000, 0x000000000000808B, 0x0000000080000001,
  0x8000000080008081, 0x8000000000008009, 0x000000000000008A,
  0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
  0x000000008000808B, 0x800000000000008B, 0x8000000000008089,
  0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
  0x000000000000800A, 0x800000008000000A, 0x8000000080008081,
  0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
];

const _keccakRot = [
  0, 1, 62, 28, 27,
  36, 44, 6, 55, 20,
  3, 10, 43, 25, 39,
  41, 45, 15, 21, 8,
  18, 2, 61, 56, 14,
];

int _rotl64(int x, int n) => n == 0 ? x : (x << n) | (x >>> (64 - n));

void _keccakF1600(Int64List a) {
  final c = Int64List(5);
  final b = Int64List(25);
  for (var round = 0; round < 24; round++) {
    for (var x = 0; x < 5; x++) {
      c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
    }
    for (var x = 0; x < 5; x++) {
      final d = c[(x + 4) % 5] ^ _rotl64(c[(x + 1) % 5], 1);
      for (var y = 0; y < 25; y += 5) {
        a[y + x] ^= d;
      }
    }
    for (var x = 0; x < 5; x++) {
      for (var y = 0; y < 5; y++) {
        final idx = x + 5 * y;
        final dst = y + 5 * ((2 * x + 3 * y) % 5);
        b[dst] = _rotl64(a[idx], _keccakRot[idx]);
      }
    }
    for (var y = 0; y < 25; y += 5) {
      for (var x = 0; x < 5; x++) {
        a[y + x] = b[y + x] ^ (~b[y + ((x + 1) % 5)] & b[y + ((x + 2) % 5)]);
      }
    }
    a[0] ^= _keccakRc[round];
  }
}

Uint8List _sha3_256(Uint8List data) {
  const rate = 136;
  final state = Int64List(25);
  final stateBytes = state.buffer.asUint8List();

  var offset = 0;
  while (offset + rate <= data.length) {
    for (var i = 0; i < rate; i++) {
      stateBytes[i] ^= data[offset + i];
    }
    _keccakF1600(state);
    offset += rate;
  }

  final rem = data.length - offset;
  for (var i = 0; i < rem; i++) {
    stateBytes[i] ^= data[offset + i];
  }
  stateBytes[rem] ^= 0x06;
  stateBytes[rate - 1] ^= 0x80;
  _keccakF1600(state);

  return Uint8List.fromList(stateBytes.sublist(0, 32));
}
