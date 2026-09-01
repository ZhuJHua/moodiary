import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 心情/状态图标（lucide，取语义色）。
class MoodIconComponent extends StatelessWidget {
  const MoodIconComponent({super.key, required this.mood, this.size = 24.0});

  final DiaryMood mood;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(mood.icon, color: mood.color, size: size);
  }
}
