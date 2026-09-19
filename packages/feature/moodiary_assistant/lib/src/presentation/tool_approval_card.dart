import 'package:moodiary_assistant/src/application/tool_approval.dart';
import 'package:moodiary_assistant/src/presentation/assistant_tool_ui.dart';
import 'package:moodiary_assistant/src/presentation/tool_approval_preview.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

const double _kInset = 8;

class ToolApprovalCard extends StatelessWidget {
  final ToolApprovalRequest request;
  final ToolApprovalPreview? preview;
  final VoidCallback onApprove;
  final VoidCallback onSkip;

  const ToolApprovalCard({
    super.key,
    required this.request,
    required this.preview,
    required this.onApprove,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final display = assistantToolDisplay(context, request.tool);
    final destructive = request.tier == .destructive;
    final preview = this.preview;
    final fg = colors.onSurfaceVariant;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: MuiRadius.inside(MuiRadius.xl, _kInset),
    );

    return MGlassSurface(
      shape: const RoundedRectangleBorder(borderRadius: MuiRadius.xl),
      child: Padding(
        padding: const .all(_kInset),
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            Padding(
              padding: const .fromLTRB(8, 6, 8, 4),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  Row(
                    children: [
                      Icon(display.icon, size: 15, color: fg),
                      const SizedBox(width: 7),
                      Text(
                        display.title,
                        style:
                            typography.labelMedium.emphasized.onSurfaceVariant,
                      ),
                      if (preview != null && preview.subtitle.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: typography.labelMedium.onSurfaceVariant
                              .copyWith(color: fg.withValues(alpha: 0.5)),
                        ),
                        Expanded(
                          child: Text(
                            preview.subtitle,
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: typography.labelMedium.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (preview == null)
                    const Padding(
                      padding: .symmetric(vertical: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    if (preview.lines.isNotEmpty) const SizedBox(height: 8),
                    for (final line in preview.lines)
                      Padding(
                        padding: const .only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: .start,
                          children: [
                            if (line.label.isNotEmpty)
                              SizedBox(
                                width: 40,
                                child: Text(
                                  line.label,
                                  style: typography.bodyMedium.onSurfaceVariant,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                line.value,
                                maxLines: 2,
                                overflow: .ellipsis,
                                style: typography.bodyMedium.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (preview.warning case final warning?)
                      Padding(
                        padding: const .only(top: 2),
                        child: Text(
                          warning,
                          style: typography.labelSmall.error,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                Padding(
                  padding: const .only(left: 8),
                  child: Text(
                    l10n.assistant.approvalOrReply,
                    style: typography.labelSmall.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(shape: buttonShape),
                  child: Text(l10n.assistant.approvalSkip),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: preview == null ? null : onApprove,
                  style: FilledButton.styleFrom(
                    shape: buttonShape,
                    backgroundColor: destructive ? colors.error : null,
                    foregroundColor: destructive ? colors.onError : null,
                  ),
                  child: Text(preview?.confirmLabel ?? l10n.common.ok),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
