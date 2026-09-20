import 'dart:io';

final String repoRoot = () {
  var dir = Directory.current;
  while (!Directory('${dir.path}/packages').existsSync()) {
    dir = dir.parent;
  }
  return dir.path;
}();
