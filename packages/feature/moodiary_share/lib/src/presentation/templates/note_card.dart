import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'share_card_template.dart';

/// 「便签纸感」模版：暖色纸底 + 顶部胶带 + 淡淡的横向格线 + 暖墨字，像一张手写便签。
/// 底色固定（暖纸色），强调（胶带）取主题种子色，不随 app 亮/暗切换。
class NoteShareCard extends StatelessWidget {
  final Diary diary;

  const NoteShareCard({super.key, required this.diary});

  static const _paper = Color(0xFFFBF3DE);
  static const _ink = Color(0xFF4A4034);
  static const _inkSoft = Color(0xFF9B8E76);

  @override
  Widget build(BuildContext context) {
    final tape = Theme.of(context).colorScheme.primary;
    return Container(
      width: kShareCardWidth,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            // 淡横线格纹铺底。
            Positioned.fill(
              child: CustomPaint(painter: _RuledLinesPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 34, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.yMMMMEEEEd().format(diary.time),
                    style: const TextStyle(
                      fontSize: 12,
                      color: _inkSoft,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    diary.title.isEmpty ? '(无标题)' : diary.title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    diary.contentText,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.85,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: _inkSoft,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '心情 ${(diary.mood * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, color: _inkSoft),
                      ),
                      const Spacer(),
                      const Text(
                        'Moodiary',
                        style: TextStyle(
                          fontSize: 12,
                          color: _inkSoft,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 顶部居中的「胶带」。
            Positioned(
              top: -10,
              left: kShareCardWidth / 2 - 34,
              child: Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: 68,
                  height: 24,
                  color: tape.withValues(alpha: 0.30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 暖纸底上的淡横线格纹。
class _RuledLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0F4A4034)
      ..strokeWidth = 1;
    const gap = 30.0;
    for (double y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RuledLinesPainter oldDelegate) => false;
}
