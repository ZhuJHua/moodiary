import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

Future<void> showPendingMoodNotice(BuildContext context) async {
  if (MoodiaryKVs.pendingMoodNotice.get() != true) return;
  MoodiaryKVs.pendingMoodNotice.set(false);
  String? version;
  try {
    version = (await AppInfo.getPackageInfo()).version;
  } catch (e, s) {
    logger.e('Mood notice version unavailable', error: e, stackTrace: s);
  }
  if (!context.mounted) return;
  final explore = await MSheet.notice<bool>(
    context,
    icon: LucideIcons.sparkles,
    title: context.l10n.insights.noticeTitle,
    subtitle: version == null || version.isEmpty
        ? null
        : context.l10n.insights.noticeSubtitle(version: version),
    hero: Column(
      mainAxisSize: .min,
      spacing: 14,
      children: [
        Row(
          children: [
            for (final mood in DiaryMood.values)
              Expanded(
                child: Column(
                  spacing: 6,
                  children: [
                    MoodGlyph(mood: mood, size: 30),
                    Text(
                      mood.label(context),
                      style:
                          context.theme.typography.labelSmall.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
          ],
        ),
        Text(
          context.l10n.insights.noticeCaption,
          textAlign: .center,
          style: context.theme.typography.bodySmall.onSurfaceVariant,
        ),
      ],
    ),
    items: [
      MNoticeItem(
        icon: LucideIcons.hash,
        title: context.l10n.insights.noticeTagsTitle,
        body: context.l10n.insights.noticeTagsBody,
      ),
      MNoticeItem(
        icon: LucideIcons.refreshCw,
        title: context.l10n.insights.noticeLevelsTitle,
        body: context.l10n.insights.noticeLevelsBody,
      ),
      MNoticeItem(
        icon: LucideIcons.chartLine,
        title: context.l10n.insights.noticeInsightsTitle,
        body: context.l10n.insights.noticeInsightsBody,
      ),
    ],
    actions: [
      MAction(label: context.l10n.insights.noticeExplore, value: true),
      MAction(
        label: context.l10n.insights.noticeDone,
        isPrimary: true,
        value: false,
      ),
    ],
  );
  if (explore == true && context.mounted) {
    const MoodInsightsRoute().push(context);
  }
}
