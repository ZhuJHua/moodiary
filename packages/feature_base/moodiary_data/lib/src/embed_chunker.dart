/// 正文分块：按空行切段、相邻段合并到 [maxChars]，超长单段硬切。
/// 返回在原文中的字符偏移（不复制文本——摘录回显按偏移切原文）。
/// 400 字符是 512 token 推理上限的保守 proxy（Qwen3 BPE 中文约 1 token/字）。
library;

typedef ChunkSpan = ({int start, int len});

List<ChunkSpan> chunkOffsets(String text, {int maxChars = 400}) {
  final spans = <ChunkSpan>[];
  var runStart = -1; // 当前累积块的起点
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
    offset += line.length + 1; // 计入被 split 吃掉的 \n（尾行多算 1 无影响）
    if (line.trim().isEmpty) {
      // 空行 = 段落边界；已累积的内容若再并入下一段会超限，flush 交给下面判断。
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
