import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import 'share_card_template.dart';

/// 「便签纸感」模版：纸底 + 顶部胶带 + 淡横向格线 + 暖墨字，像一张手写便签。
/// 随传入的 [brightness] 切浅色暖纸 / 深色暖炭底；胶带取主题种子色。
class NoteShareCard extends StatelessWidget {
  final Diary diary;
  final Brightness brightness;

  const NoteShareCard({
    super.key,
    required this.diary,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final dark = brightness == .dark;
    final tape = Theme.of(context).colorScheme.primary;
    final paper = dark ? const Color(0xFF2A2621) : const Color(0xFFFBF3DE);
    final ink = dark ? const Color(0xFFE9E0CB) : const Color(0xFF4A4034);
    final inkSoft = dark ? const Color(0xFFA1957C) : const Color(0xFF9B8E76);
    final line = dark ? const Color(0x14E9E0CB) : const Color(0x0F4A4034);
    return Container(
      width: kShareCardWidth,
      decoration: BoxDecoration(color: paper, borderRadius: .circular(6)),
      child: ClipRRect(
        borderRadius: .circular(6),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RuledLinesPainter(line)),
            ),
            Padding(
              padding: const .fromLTRB(28, 34, 28, 24),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  Text(
                    TimeFormat.fullDate(diary.time),
                    style: TextStyle(
                      fontSize: 12,
                      color: inkSoft,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    diary.title.isEmpty ? '(无标题)' : diary.title,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: .w700,
                      color: ink,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    diary.contentText,
                    style: TextStyle(fontSize: 15, height: 1.85, color: ink),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Icon(LucideIcons.heart, size: 13, color: inkSoft),
                      const SizedBox(width: 5),
                      Text(
                        '心情 ${(diary.mood * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, color: inkSoft),
                      ),
                      const Spacer(),
                      Text(
                        'Moodiary',
                        style: TextStyle(
                          fontSize: 12,
                          color: inkSoft,
                          fontWeight: .w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: -10,
              left: kShareCardWidth / 2 - 34,
              child: Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: 68,
                  height: 24,
                  color: tape.withValues(alpha: dark ? 0.42 : 0.30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 纸底上的淡横线格纹。
class _RuledLinesPainter extends CustomPainter {
  final Color color;

  const _RuledLinesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const gap = 30.0;
    for (double y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RuledLinesPainter oldDelegate) =>
      oldDelegate.color != color;
}
