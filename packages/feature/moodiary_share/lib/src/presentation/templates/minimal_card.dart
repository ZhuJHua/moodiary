import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'share_card_template.dart';

/// 「简约」模版：干净卡片，标题 / 日期 / 正文 / 心情。强调色取自当前主题种子；
/// 底色随传入的 [brightness]（浅色白底、深色近黑底），与 app 主题解耦、可在分享页手动切。
class MinimalShareCard extends StatelessWidget {
  final Diary diary;
  final Brightness brightness;

  const MinimalShareCard({
    super.key,
    required this.diary,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final bg = dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final titleColor = dark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A);
    final metaColor = dark ? const Color(0xFF8E8E93) : const Color(0xFF9E9E9E);
    final bodyColor = dark ? const Color(0xFFD6D6DB) : const Color(0xFF333333);
    final brand = dark ? const Color(0xFF5A5A5E) : const Color(0xFFC2C2C2);
    return Container(
      width: kShareCardWidth,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 32, height: 4, color: accent),
          const SizedBox(height: 18),
          Text(
            diary.title.isEmpty ? '(无标题)' : diary.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: titleColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.yMMMMd().add_Hm().format(diary.time),
            style: TextStyle(fontSize: 12, color: metaColor),
          ),
          const SizedBox(height: 20),
          Text(
            diary.contentText,
            style: TextStyle(fontSize: 15, height: 1.75, color: bodyColor),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: dark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '心情 ${(diary.mood * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: dark ? accent.withValues(alpha: 0.95) : accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Moodiary',
                style: TextStyle(
                  fontSize: 12,
                  color: brand,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
