import 'package:freezed_annotation/freezed_annotation.dart';

part 'reasoning_control.freezed.dart';
part 'reasoning_control.g.dart';

enum ReasoningControlType {
  toggle,

  effort,

  budgetTokens;

  static ReasoningControlType? fromJsonName(String? name) => switch (name) {
    'toggle' => toggle,
    'effort' => effort,
    'budget_tokens' => budgetTokens,
    _ => null,
  };
}

@freezed
abstract class ReasoningControl with _$ReasoningControl {
  const factory ReasoningControl({
    required ReasoningControlType type,

    @Default(<String>[]) List<String> values,

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
