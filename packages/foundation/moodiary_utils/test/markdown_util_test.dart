import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  group('MarkdownConverter.convert', () {
    test('空输入返回空串', () {
      expect(MarkdownConverter.convert(''), '');
    });

    test('剥离标题井号', () {
      expect(MarkdownConverter.convert('# 标题'), '标题');
      expect(MarkdownConverter.convert('### 三级标题 ###'), '三级标题');
    });

    test('不误伤 #标签', () {
      expect(MarkdownConverter.convert('#标签'), '#标签');
    });

    test('剥离强调标记保留文字', () {
      expect(MarkdownConverter.convert('这是 **粗体** 与 *斜体*'), '这是 粗体 与 斜体');
      expect(MarkdownConverter.convert('~~删除线~~'), '删除线');
    });

    test('词内下划线不被当作斜体', () {
      expect(MarkdownConverter.convert('snake_case_name'), 'snake_case_name');
    });

    test('空 alt 图片不留下残留的感叹号', () {
      expect(MarkdownConverter.convert('![](image-abc.jpg)'), '');
    });

    test('带 alt 图片保留 alt', () {
      expect(MarkdownConverter.convert('![一只猫](image-cat.jpg)'), '一只猫');
    });

    test('链接保留显示文本丢弃 URL', () {
      expect(
        MarkdownConverter.convert('看 [官网](https://example.com) 了解'),
        '看 官网 了解',
      );
    });

    test('代码围栏去掉标记保留内容', () {
      const md = '```dart\nfinal x = 1;\n```';
      expect(MarkdownConverter.convert(md), 'final x = 1;');
    });

    test('行内代码去掉反引号', () {
      expect(MarkdownConverter.convert('运行 `flutter test`'), '运行 flutter test');
    });

    test('引用去掉前缀', () {
      expect(MarkdownConverter.convert('> 一句引用'), '一句引用');
    });

    test('无序列表与任务清单去掉标记', () {
      const md = '- 苹果\n- 香蕉\n- [ ] 待办\n- [x] 已完成';
      expect(MarkdownConverter.convert(md), '苹果\n香蕉\n待办\n已完成');
    });

    test('有序列表去掉编号', () {
      expect(MarkdownConverter.convert('1. 第一\n2. 第二'), '第一\n第二');
    });

    test('分隔线整行删除', () {
      expect(MarkdownConverter.convert('上\n\n---\n\n下'), '上\n\n下');
    });

    test('表格去掉管道与分隔行', () {
      const md = '| 名称 | 值 |\n| --- | --- |\n| A | 1 |';
      expect(MarkdownConverter.convert(md), '名称  值\nA  1');
    });

    test('数学公式去掉定界符', () {
      expect(MarkdownConverter.convert(r'质能方程 $E=mc^2$'), '质能方程 E=mc^2');
    });

    test('反转义还原字面字符', () {
      expect(
        MarkdownConverter.convert(r'价格 \$100 与 \*星号\*'),
        r'价格 $100 与 *星号*',
      );
    });

    test('去除 HTML 标签', () {
      expect(MarkdownConverter.convert('<div>内容</div>'), '内容');
    });

    test('折叠多余空行并 trim', () {
      expect(MarkdownConverter.convert('\n\n甲\n\n\n\n乙\n\n'), '甲\n\n乙');
    });

    test('综合用例', () {
      const md = '''
# 今天的日记

去 [公园](https://park) 散步，拍了 ![](image-1.jpg) 一张照片。

> 心情**很好**

- 跑步
- 看书
''';
      expect(
        MarkdownConverter.convert(md),
        '今天的日记\n\n去 公园 散步，拍了  一张照片。\n\n心情很好\n\n跑步\n看书',
      );
    });
  });
}
