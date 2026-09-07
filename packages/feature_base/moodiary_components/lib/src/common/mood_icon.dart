import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_models/moodiary_models.dart';

class MoodIconComponent extends StatelessWidget {
  const MoodIconComponent({super.key, required this.mood, this.size = 24.0});

  final DiaryMood mood;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(mood.icon, color: mood.color, size: size);
  }
}
