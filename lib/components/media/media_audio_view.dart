import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/components/audio_player/audio_player_view.dart';
import 'package:moodiary/main.dart';

class MediaAudioComponent extends StatelessWidget {
  final DateTime dateTime;
  final List<String> audioList;

  const MediaAudioComponent({
    super.key,
    required this.dateTime,
    required this.audioList,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat.yMMMEd().format(dateTime),
                style: textStyle.titleSmall?.copyWith(
                  color: colorScheme.secondary,
                ),
              ),
              Text(
                l10n.mediaAudioCount(audioList.length),
                style: textStyle.labelMedium?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return AudioPlayerComponent(path: audioList[index]);
          },
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: audioList.length,
        ),
      ],
    );
  }
}
