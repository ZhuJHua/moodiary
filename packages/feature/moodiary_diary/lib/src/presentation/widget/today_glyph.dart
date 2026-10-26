import 'package:moodiary_components/moodiary_components.dart';

// lucide 无整套数字日历图标，用日历框叠文字实现
class TodayGlyph extends StatelessWidget {
  final int day;

  const TodayGlyph({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: Stack(
        children: [
          const Center(child: Icon(LucideIcons.calendar, size: 24)),
          Positioned.fill(
            top: 7,
            child: Center(
              child: Text(
                '$day',
                maxLines: 1,
                style: context.theme.typography.labelSmall.emphasized.onSurface
                    .copyWith(fontSize: 9, height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
