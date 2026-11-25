library;

typedef ChunkSpan = ({int start, int len});

// 400 字符 ≈ 512 token 推理上限的保守 proxy（Qwen3 BPE 中文约 1 token/字）
List<ChunkSpan> chunkOffsets(String text, {int maxChars = 400}) {
  final spans = <ChunkSpan>[];
  var runStart = -1;
  var runEnd = -1;

  void flush() {
    if (runStart < 0) return;
    var s = runStart;
    var remaining = runEnd - runStart;
    while (remaining > maxChars) {
      spans.add((start: s, len: maxChars));
      s += maxChars;
      remaining -= maxChars;
    }
    if (remaining > 0) spans.add((start: s, len: remaining));
    runStart = -1;
    runEnd = -1;
  }

  var offset = 0;
  for (final line in text.split('\n')) {
    final lineStart = offset;
    offset += line.length + 1; // +1 补回 split 吃掉的 \n（尾行多算 1 无影响）
    if (line.trim().isEmpty) {
      continue;
    }
    if (runStart < 0) {
      runStart = lineStart;
      runEnd = lineStart + line.length;
    } else if ((lineStart + line.length) - runStart <= maxChars) {
      runEnd = lineStart + line.length;
    } else {
      flush();
      runStart = lineStart;
      runEnd = lineStart + line.length;
    }
  }
  flush();
  return spans;
}
