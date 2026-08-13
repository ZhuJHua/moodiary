import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:mui/mui.dart';

import '../../l10n/mui_l10n.dart';

/// 起手色板。**不是**主题预置档 —— 点一格等于往自定义色里填一个值，落库的是 ARGB
/// 而不是索引，所以改动这张表不会动到任何人已经选好的颜色。
/// 前三格是中性锚点，其余沿用仓里那套传统色的色值。
const List<Color> kAccentSwatches = [
  Color(0xFF0A0A0A),
  Color(0xFF525252),
  Color(0xFFA3A3A3),
  Color(0xFFA72126),
  Color(0xFFC2703A),
  Color(0xFFECD452),
  Color(0xFF4F794A),
  Color(0xFF2E59A7),
  Color(0xFF45465E),
];

/// MColorPicker 的弹层入口。按组件归类的静态方法，替代原来的 show* 顶层函数。
abstract final class MColorPicker {
  /// 取色弹窗。返回选中的颜色；取消 / 点遮罩 / 返回键都返回 null。
  ///
  /// 只干调色这一件事 —— 色板与生成结果留在调用方页面上。`MAlert.show` 的卡片
  /// 宽度上限 340（内容区约 308），塞不下更多东西，小屏上也会顶到安全区。
  static Future<Color?> show(
    BuildContext context, {
    required Color initialColor,
  }) async {
    // 弹窗按钮的返回值是静态的，用可变 holder 承接内容区的实时编辑结果，
    // 按钮只负责回答「确认还是取消」。
    final draft = _ColorDraft(initialColor);
    final confirmed = await MAlert.show<bool>(
      context,
      title: context.muiL10n.colorPickerTitle,
      content: _ColorPickerContent(draft: draft),
      actions: [
        MAction(label: context.muiL10n.cancel, value: false),
        MAction(label: context.muiL10n.ok, value: true, isPrimary: true),
      ],
    );
    return confirmed == true ? draft.color : null;
  }
}

class _ColorDraft {
  /// 真源是 [HSVColor] 而不是 [Color]：`HSVColor.fromColor` 在 `r == g == b` 时把色相
  /// 抹成 0、明度为 0 时把饱和度抹成 0。拿 Color 当真源，用户把明度拖到底再拖回来，
  /// 色相和饱和度就永久丢了。
  HSVColor hsv;

  _ColorDraft(Color initial) : hsv = HSVColor.fromColor(initial);

  Color get color => hsv.toColor();
}

enum _InputMode {
  hex,
  rgb,
  hsv,
  hsl;

  _InputMode get next =>
      _InputMode.values[(index + 1) % _InputMode.values.length];
}

class _ColorPickerContent extends StatefulWidget {
  final _ColorDraft draft;

  const _ColorPickerContent({required this.draft});

  @override
  State<_ColorPickerContent> createState() => _ColorPickerContentState();
}

class _ColorPickerContentState extends State<_ColorPickerContent> {
  _InputMode _mode = .hex;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  HSVColor get _hsv => widget.draft.hsv;

  @override
  void initState() {
    super.initState();
    for (final key in const ['hex', 'a', 'b', 'c']) {
      _controllers[key] = TextEditingController();
      _focusNodes[key] = FocusNode();
    }
    _syncFields();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// 把模型写回输入框。**跳过持有焦点的那个** —— 否则用户每敲一个字符，
  /// `controller.text = …` 就把光标弹回行首。
  void _syncFields() {
    void put(String key, String value) {
      if (_focusNodes[key]!.hasFocus) return;
      final controller = _controllers[key]!;
      if (controller.text == value) return;
      controller.text = value;
    }

    final color = widget.draft.color;
    switch (_mode) {
      case .hex:
        put('hex', hexOfColor(color).substring(1));
      case .rgb:
        put('a', '${_byteOf(color.r)}');
        put('b', '${_byteOf(color.g)}');
        put('c', '${_byteOf(color.b)}');
      case .hsv:
        put('a', '${_hsv.hue.round()}');
        put('b', '${(_hsv.saturation * 100).round()}');
        put('c', '${(_hsv.value * 100).round()}');
      case .hsl:
        final hsl = _hsvToHsl(_hsv);
        put('a', '${hsl.hue.round()}');
        put('b', '${(hsl.saturation * 100).round()}');
        put('c', '${(hsl.lightness * 100).round()}');
    }
  }

  void _commit(HSVColor next) {
    setState(() => widget.draft.hsv = next);
    _syncFields();
  }

  void _commitColor(Color color) {
    // 走 Color 的入口（HEX / RGB）没有独立的色相信息，只能反算；灰色反算出来的 0°
    // 会覆盖掉用户之前调好的色相，所以饱和度为 0 时留住旧色相。
    final parsed = HSVColor.fromColor(color);
    _commit(parsed.saturation == 0 ? parsed.withHue(_hsv.hue) : parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        _SaturationValuePanel(
          hsv: _hsv,
          onChanged: (saturation, value) =>
              _commit(_hsv.withSaturation(saturation).withValue(value)),
        ),
        const SizedBox(height: 13),
        _HueSlider(
          hue: _hsv.hue,
          onChanged: (hue) => _commit(_hsv.withHue(hue)),
        ),
        const SizedBox(height: 14),
        _buildFields(),
      ],
    );
  }

  Widget _buildFields() {
    // 模式按钮标的是**下一档**，点一下轮换 HEX → RGB → HSV → HSL。
    final rotate = _ModeButton(
      label: _mode.next.name.toUpperCase(),
      onTap: () => setState(() {
        _mode = _mode.next;
        _syncFields();
      }),
    );

    if (_mode == .hex) {
      return Row(
        spacing: 8,
        children: [
          Expanded(
            child: _PickerField(
              controller: _controllers['hex']!,
              focusNode: _focusNodes['hex']!,
              label: 'HEX',
              formatters: [
                const _UpperCaseFormatter(),
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-FxX#＃]')),
              ],
              maxLength: 6,
              onChanged: (text) {
                final parsed = parseHexColor(text);
                if (parsed != null) _commitColor(parsed);
              },
            ),
          ),
          rotate,
        ],
      );
    }

    final labels = switch (_mode) {
      .rgb => const ['R', 'G', 'B'],
      .hsv => const ['H', 'S', 'V'],
      _ => const ['H', 'S', 'L'],
    };
    return Row(
      spacing: 8,
      children: [
        for (final (index, key) in const ['a', 'b', 'c'].indexed)
          Expanded(
            child: _PickerField(
              controller: _controllers[key]!,
              focusNode: _focusNodes[key]!,
              label: labels[index],
              formatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3,
              onChanged: (_) => _onNumbersChanged(),
            ),
          ),
        rotate,
      ],
    );
  }

  void _onNumbersChanged() {
    double read(String key, double max) =>
        ((double.tryParse(_controllers[key]!.text) ?? 0) / max).clamp(0.0, 1.0);

    if (_mode == .rgb) {
      int byte(String key) =>
          (int.tryParse(_controllers[key]!.text) ?? 0).clamp(0, 255);
      _commitColor(Color.fromARGB(255, byte('a'), byte('b'), byte('c')));
      return;
    }
    // 360 与 0 同值，但 HSVColor.fromAHSV 断言 hue <= 360，输入 361 会在 debug 直接崩。
    final hue = (double.tryParse(_controllers['a']!.text) ?? 0) % 360;
    final second = read('b', 100);
    final third = read('c', 100);
    _commit(
      _mode == .hsl
          ? _hslToHsv(HSLColor.fromAHSL(1, hue, second, third))
          : HSVColor.fromAHSV(1, hue, second, third),
    );
  }
}

// ───────────────────────── 面板 ─────────────────────────

/// 饱和度（横）× 明度（纵）方块。三层叠加：底色相 → 向右透白 → 向下透黑。
class _SaturationValuePanel extends StatelessWidget {
  final HSVColor hsv;
  final void Function(double saturation, double value) onChanged;

  const _SaturationValuePanel({required this.hsv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 126.0;

        void handle(Offset local) => onChanged(
          (local.dx / width).clamp(0.0, 1.0),
          1 - (local.dy / height).clamp(0.0, 1.0),
        );

        return GestureDetector(
          onPanDown: (details) => handle(details.localPosition),
          onPanUpdate: (details) => handle(details.localPosition),
          child: ClipRRect(
            borderRadius: MuiRadius.md,
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: .bottomCenter,
                          end: .topCenter,
                          colors: [Colors.black, Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hsv.saturation * width - _kKnobSize / 2,
                    top: (1 - hsv.value) * height - _kKnobSize / 2,
                    child: _Knob(color: hsv.toColor()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueSlider({required this.hue, required this.onChanged});

  static const List<Color> _spectrum = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void handle(Offset local) =>
            onChanged(((local.dx / width).clamp(0.0, 1.0)) * 360);

        return GestureDetector(
          onPanDown: (details) => handle(details.localPosition),
          onPanUpdate: (details) => handle(details.localPosition),
          child: SizedBox(
            height: _kKnobSize,
            child: Stack(
              alignment: .centerLeft,
              children: [
                Container(
                  height: 13,
                  decoration: const BoxDecoration(
                    borderRadius: .all(.circular(7)),
                    gradient: LinearGradient(colors: _spectrum),
                  ),
                ),
                Positioned(
                  left: (hue / 360) * width - _kKnobSize / 2,
                  child: _Knob(
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

const double _kKnobSize = 20;

class _Knob extends StatelessWidget {
  final Color color;

  const _Knob({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kKnobSize,
      height: _kKnobSize,
      decoration: BoxDecoration(
        color: color,
        shape: .circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4),
        ],
      ),
    );
  }
}

// ───────────────────────── 输入 ─────────────────────────

class _PickerField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final List<TextInputFormatter> formatters;
  final int maxLength;
  final ValueChanged<String> onChanged;

  const _PickerField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.formatters,
    required this.maxLength,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MField(
      controller: controller,
      focusNode: focusNode,
      label: label,
      maxLength: maxLength,
      minHeight: 42,
      keyboardType: label == 'HEX' ? null : .number,
      textInputAction: .done,
      inputFormatters: formatters,
      onChanged: onChanged,
      onSubmitted: onChanged,
      // 清除键在三列并排时会把数字挤没。
      trailing: const SizedBox.shrink(),
    );
  }
}

/// 模式轮换键。标的是**下一档**，省下一整行分段控件的高度。
class _ModeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ModeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Padding(
      // 与输入框对齐：MField 的 label 占了上方一行。
      padding: const .only(top: 20),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: MuiRadius.md,
        child: InkWell(
          borderRadius: MuiRadius.md,
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 42,
            child: Center(
              child: Text(
                label,
                style: context
                    .theme
                    .typography
                    .labelSmall
                    .emphasized
                    .onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 大写化时必须把 selection 迁过来，否则光标每敲一个字符就跳回行首。
class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return TextEditingValue(
      text: upper,
      selection: newValue.selection,
      composing: .empty,
    );
  }
}

// ───────────────────────── 色板 ─────────────────────────

/// 一排起手色。放在页面上而不是弹窗里 —— 弹窗只负责调色。
class MSwatchRow extends StatelessWidget {
  final List<Color> swatches;
  final Color selected;
  final ValueChanged<Color> onSelected;

  const MSwatchRow({
    super.key,
    this.swatches = kAccentSwatches,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        for (final swatch in swatches)
          Expanded(
            child: Semantics(
              // Color 的 == 比的是浮点分量，且 HSV 往返不是恒等变换，
              // 判定选中只能比 8 位整数。
              selected: swatch.toARGB32() == selected.toARGB32(),
              child: AspectRatio(
                aspectRatio: 1,
                child: Material(
                  color: swatch,
                  borderRadius: MuiRadius.sm,
                  child: InkWell(
                    borderRadius: MuiRadius.sm,
                    onTap: () => onSelected(swatch),
                    child: swatch.toARGB32() == selected.toARGB32()
                        ? Icon(
                            LucideIcons.check,
                            size: 15,
                            // 色板是原始种子色，没有配套的 onXxx 角色可用，
                            // 只能按亮度自己挑黑白墨色。
                            color: swatch.computeLuminance() > 0.45
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── 色彩模型换算 ─────────────────────────

/// 宽容解析：接受 3 / 6 位，`#`、全角 `＃`、`0x` 前缀与空白都剥掉，大小写不敏感。
/// 不收 alpha —— 8 位写法在 CSS（RRGGBBAA）与 Flutter（AARRGGBB）之间有字节序歧义，
/// 而这里要的只是一个强调色种子。
Color? parseHexColor(String raw) {
  var text = raw.trim().replaceAll(RegExp(r'[\s#＃]'), '');
  if (text.length > 1 && text[0] == '0' && (text[1] == 'x' || text[1] == 'X')) {
    text = text.substring(2);
  }
  if (text.length == 3) {
    text = text.split('').map((char) => '$char$char').join();
  }
  if (text.length != 6) return null;
  final value = int.tryParse(text, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

String hexOfColor(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

/// 与 `Color.toARGB32()` 同一条量化公式（`_floatToInt8`）。用 floor / truncate
/// 会让 RGB 数字和同屏的 HEX 差 1。
int _byteOf(double channel) => (channel * 255.0).round().clamp(0, 255);

/// SDK 只给 RGB↔HSV 与 RGB↔HSL，不给 HSV↔HSL 直转；经 Color 中转是双重有损
/// 而且会丢灰色的色相，所以两边都自己算。
HSLColor _hsvToHsl(HSVColor hsv) {
  final lightness = hsv.value * (1 - hsv.saturation / 2);
  final saturation = (lightness == 0 || lightness == 1)
      ? 0.0
      : (hsv.value - lightness) / math.min(lightness, 1 - lightness);
  return HSLColor.fromAHSL(
    hsv.alpha,
    hsv.hue,
    saturation.clamp(0.0, 1.0),
    lightness.clamp(0.0, 1.0),
  );
}

HSVColor _hslToHsv(HSLColor hsl) {
  final value =
      hsl.lightness +
      hsl.saturation * math.min(hsl.lightness, 1 - hsl.lightness);
  final saturation = value == 0 ? 0.0 : 2 * (1 - hsl.lightness / value);
  return HSVColor.fromAHSV(
    hsl.alpha,
    hsl.hue,
    saturation.clamp(0.0, 1.0),
    value.clamp(0.0, 1.0),
  );
}
