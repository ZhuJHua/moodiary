import 'dart:convert';

/// Quill Delta（richText 落库形态）→ TipTap 文档 JSON 串，供「迁移到 tiptap」用。
///
/// 直接产出 ProseMirror 节点树（不经 markdown 中转），故图片/音频/视频都还原为对应的一等节点
/// （image / audio / video），不会退化成图片，也无需任何文件名前缀约定。
/// 覆盖：行内 bold/italic/underline/strike/code/link（color/background/align 在 tiptap 当前 schema
/// 无对应，丢弃只保留文字）；块级 heading(h1-6)/bulletList/orderedList/taskList(复选列表)/blockquote/
/// codeBlock；三种 embed。
///
/// 容错：JSON 解析失败 / 非 Delta 数组返回 null，调用方据此跳过该篇（保留原 Delta）。
class QuillDeltaToTiptap {
  const QuillDeltaToTiptap._();

  static String? convert(String deltaJson) {
    final List<dynamic> ops;
    try {
      final decoded = jsonDecode(deltaJson);
      if (decoded is! List) return null;
      ops = decoded;
    } catch (_) {
      return null;
    }

    // 1) 解析为「行」：文本 op 按 \n 切，换行处用行级属性（header/list/blockquote/code-block）收行。
    final lines = <_Line>[];
    var current = _Line();
    void close(Map<String, dynamic> attrs) {
      current.attrs = attrs;
      lines.add(current);
      current = _Line();
    }

    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      final attrs = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : const <String, dynamic>{};
      if (insert is String) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) current.segs.add(_Seg.text(parts[i], attrs));
          if (i < parts.length - 1) close(Map<String, dynamic>.from(attrs));
        }
      } else if (insert is Map) {
        final kind = insert.containsKey('image')
            ? 'image'
            : insert.containsKey('audio')
            ? 'audio'
            : insert.containsKey('video')
            ? 'video'
            : null;
        final name = kind == null ? null : insert[kind];
        if (kind != null && name is String && name.isNotEmpty) {
          current.segs.add(_Seg.embed(kind, name));
        }
      }
    }
    if (current.segs.isNotEmpty) close(const <String, dynamic>{});

    final content = _buildBlocks(lines);
    return jsonEncode({'type': 'doc', 'content': content});
  }

  static List<Map<String, dynamic>> _buildBlocks(List<_Line> lines) {
    final blocks = <Map<String, dynamic>>[];

    // 分组累积器：相邻 list 项合一个列表、相邻 blockquote 行合一个引用、相邻 code-block 行合一个代码块。
    List<Map<String, dynamic>>? listItems;
    String? listType;
    List<Map<String, dynamic>>? quoteBlocks;
    List<String>? codeLines;

    void flushList() {
      if (listItems != null) {
        blocks.add({'type': listType, 'content': listItems});
        listItems = null;
        listType = null;
      }
    }

    void flushQuote() {
      if (quoteBlocks != null) {
        blocks.add({'type': 'blockquote', 'content': quoteBlocks});
        quoteBlocks = null;
      }
    }

    void flushCode() {
      if (codeLines != null) {
        final text = codeLines!.join('\n');
        blocks.add({
          'type': 'codeBlock',
          if (text.isNotEmpty)
            'content': [
              {'type': 'text', 'text': text},
            ],
        });
        codeLines = null;
      }
    }

    for (final line in lines) {
      final la = line.attrs;
      final isCode = la['code-block'] != null && la['code-block'] != false;

      if (isCode) {
        flushList();
        flushQuote();
        // codeBlock 只能容纳文本：行内 embed 在此切断代码块、以一等媒体节点保留
        // （丢弃会连带丢文件引用，清理孤儿文件时媒体被永久删除）。
        final text = line.segs
            .where((s) => s.embed == null)
            .map((s) => s.text)
            .join();
        final embeds = line.segs.where((s) => s.embed != null);
        if (text.isNotEmpty || embeds.isEmpty) {
          codeLines ??= [];
          codeLines!.add(text);
        }
        for (final seg in embeds) {
          flushCode();
          blocks.add(_embedNode(seg));
        }
        continue;
      }
      flushCode();

      // 这一行产出的块节点。含 embed 时：文本段聚成 paragraph、embed 段各成对应节点。
      final produced = _lineBlocks(line);

      final list = la['list'];
      if (list != null) {
        flushQuote();
        // Quill 复选列表（checked/unchecked）→ taskList；ordered→orderedList；其余→bulletList。
        final isCheck = list == 'checked' || list == 'unchecked';
        final type = isCheck
            ? 'taskList'
            : list == 'ordered'
            ? 'orderedList'
            : 'bulletList';
        if (listItems == null || listType != type) {
          flushList();
          listItems = [];
          listType = type;
        }
        listItems!.add(
          isCheck
              ? {
                  'type': 'taskItem',
                  'attrs': {'checked': list == 'checked'},
                  'content': produced,
                }
              : {'type': 'listItem', 'content': produced},
        );
      } else if (la['blockquote'] == true) {
        flushList();
        quoteBlocks ??= [];
        quoteBlocks!.addAll(produced);
      } else {
        flushList();
        flushQuote();
        blocks.addAll(produced);
      }
    }
    flushList();
    flushQuote();
    flushCode();

    // doc 至少要有一个块。
    if (blocks.isEmpty) blocks.add({'type': 'paragraph'});
    return blocks;
  }

  /// 一行 → 块节点列表（heading/paragraph + 内联 embed 拆出的 image/audio/video）。
  static List<Map<String, dynamic>> _lineBlocks(_Line line) {
    final la = line.attrs;
    final hasEmbed = line.segs.any((s) => s.embed != null);

    if (hasEmbed) {
      final out = <Map<String, dynamic>>[];
      final buf = <Map<String, dynamic>>[];
      void flushPara() {
        if (buf.isNotEmpty) {
          out.add({'type': 'paragraph', 'content': List.of(buf)});
          buf.clear();
        }
      }

      for (final seg in line.segs) {
        if (seg.embed != null) {
          flushPara();
          out.add(_embedNode(seg));
        } else {
          final node = _textNode(seg);
          if (node != null) buf.add(node);
        }
      }
      flushPara();
      if (out.isEmpty) out.add({'type': 'paragraph'});
      return out;
    }

    final inline = <Map<String, dynamic>>[];
    for (final seg in line.segs) {
      final node = _textNode(seg);
      if (node != null) inline.add(node);
    }

    final header = la['header'];
    if (header is int && header >= 1) {
      return [
        {
          'type': 'heading',
          'attrs': {'level': header > 6 ? 6 : header},
          if (inline.isNotEmpty) 'content': inline,
        },
      ];
    }
    return [
      {'type': 'paragraph', if (inline.isNotEmpty) 'content': inline},
    ];
  }

  static Map<String, dynamic>? _textNode(_Seg seg) {
    if (seg.text.isEmpty) return null;
    final a = seg.attrs;
    final marks = <Map<String, dynamic>>[];
    if (a['bold'] == true) marks.add({'type': 'bold'});
    if (a['italic'] == true) marks.add({'type': 'italic'});
    if (a['underline'] == true) marks.add({'type': 'underline'});
    if (a['strike'] == true) marks.add({'type': 'strike'});
    if (a['code'] == true) marks.add({'type': 'code'});
    final link = a['link'];
    if (link is String && link.isNotEmpty) {
      marks.add({
        'type': 'link',
        'attrs': {'href': link},
      });
    }
    return {
      'type': 'text',
      'text': seg.text,
      if (marks.isNotEmpty) 'marks': marks,
    };
  }

  static Map<String, dynamic> _embedNode(_Seg seg) {
    switch (seg.embed) {
      case 'image':
        return {
          'type': 'image',
          'attrs': {'src': seg.name},
        };
      case 'audio':
        return {
          'type': 'audio',
          'attrs': {'filename': seg.name},
        };
      case 'video':
        return {
          'type': 'video',
          'attrs': {'filename': seg.name},
        };
      default:
        return {'type': 'paragraph'};
    }
  }
}

class _Line {
  final List<_Seg> segs = [];
  Map<String, dynamic> attrs = const {};
}

/// 行内一段：文本段（text+attrs）或 embed 段（kind=image/audio/video + 裸文件名 name）。
class _Seg {
  final String text;
  final Map<String, dynamic> attrs;
  final String? embed;
  final String name;
  _Seg.text(this.text, this.attrs) : embed = null, name = '';
  _Seg.embed(this.embed, this.name) : text = '', attrs = const {};
}
