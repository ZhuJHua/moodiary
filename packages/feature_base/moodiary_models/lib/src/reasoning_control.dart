import 'package:freezed_annotation/freezed_annotation.dart';

part 'reasoning_control.freezed.dart';
part 'reasoning_control.g.dart';

/// models.dev `reasoning_options[].type`。一个模型可以同时给出多种控制
/// （常见的是 effort + budget_tokens 并存）。
enum ReasoningControlType {
  /// 只能开关，没有档位。
  toggle,

  /// 有档位，取值见 [ReasoningControl.values]。
  effort,

  /// 给 token 预算，范围见 [ReasoningControl.min] / [ReasoningControl.max]。
  budgetTokens;

  static ReasoningControlType? fromJsonName(String? name) => switch (name) {
    'toggle' => toggle,
    'effort' => effort,
    'budget_tokens' => budgetTokens,
    _ => null,
  };
}

/// 一条思考控制能力。**空列表与缺失不是一回事**：`reasoning_options: []` 表示
/// 「模型会思考但调用方无从控制」，缺失表示目录没标（reasoning=true 时属于坏数据）。
@freezed
abstract class ReasoningControl with _$ReasoningControl {
  const factory ReasoningControl({
    required ReasoningControlType type,

    /// effort 型的档位。取值来自 models.dev，可能含
    /// `null` / `none` / `minimal` / `low` / `medium` / `high` / `xhigh` / `max` / `default`。
    @Default(<String>[]) List<String> values,

    /// budget_tokens 型的下界 / 上界（目录只在核实过时才给）。
    int? min,
    int? max,
  }) = _ReasoningControl;

  const ReasoningControl._();

  factory ReasoningControl.fromJson(Map<String, dynamic> json) =>
      _$ReasoningControlFromJson(json);

  static ReasoningControl? fromModelsDev(Map<String, dynamic> json) {
    final type = ReasoningControlType.fromJsonName(json['type'] as String?);
    if (type == null) return null;
    final rawValues = json['values'];
    return ReasoningControl(
      type: type,
      values: rawValues is List
          ? rawValues.whereType<String>().toList()
          : const [],
      min: (json['min'] as num?)?.toInt(),
      max: (json['max'] as num?)?.toInt(),
    );
  }
}
