import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'share_card_template.dart';

/// 「简约」模版：干净的浅色卡片，标题 / 日期 / 正文 / 心情。强调色取自当前主题种子，
/// 但底色固定为浅色 —— 无论 app 处于亮/暗模式，导出的都是一致的浅色卡片。
class MinimalShareCard extends StatelessWidget {
  final Diary diary;

  const MinimalShareCard({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: kShareCardWidth,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.yMMMMd().add_Hm().format(diary.time),
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 20),
          Text(
            diary.contentText,
            style: const TextStyle(
              fontSize: 15,
              height: 1.75,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '心情 ${(diary.mood * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Moodiary',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFC2C2C2),
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
