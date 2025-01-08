import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/media_type.dart';
import 'package:mood_diary/components/loading/loading.dart';
import 'package:mood_diary/components/lottie_modal/lottie_modal.dart';
import 'package:mood_diary/components/media/media_audio_view.dart';
import 'package:mood_diary/components/media/media_video_view.dart';
import 'package:refreshed/refreshed.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../components/media/media_image_view.dart';
import '../../../main.dart';
import 'media_logic.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  static final iconMap = {
    MediaType.image: Icons.image_rounded,
    MediaType.audio: Icons.audiotrack_rounded,
    MediaType.video: Icons.movie_rounded
  };

  static final textMap = {
    MediaType.image: l10n.mediaTypeImage,
    MediaType.audio: l10n.mediaTypeAudio,
    MediaType.video: l10n.mediaTypeVideo
  };

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(MediaLogic());
    final state = Bind.find<MediaLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;
    return GetBuilder<MediaLogic>(
      assignId: true,
      builder: (_) {
        return SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  AppBar(
                    title: Text(l10n.homeNavigatorMedia),
                    actions: [
                      IconButton(
                          onPressed: () async {
                            var res = await showCalendarDatePicker2Dialog(
                                context: context,
                                config:
                                    CalendarDatePicker2WithActionButtonsConfig(
                                  calendarViewMode: CalendarDatePicker2Mode.day,
                                  calendarType: CalendarDatePicker2Type.single,
                                  hideMonthPickerDividers: true,
                                  hideYearPickerDividers: true,
                                  useAbbrLabelForMonthModePicker: true,
                                  allowSameValueSelection: true,
                                  dayTextStylePredicate: (
                                      {required DateTime date}) {
                                    return state.dateTimeList.contains(date)
                                        ? textStyle.labelMedium?.copyWith(
                                            color: colorScheme.primary)
                                        : null;
                                  },
                                  selectableDayPredicate: (DateTime date) {
                                    return state.dateTimeList.contains(date);
                                  },
                                ),
                                borderRadius:
                                    AppBorderRadius.mediumBorderRadius,
                                dialogSize: const Size(300, 400));
                            if (res != null && res.isNotEmpty) {
                              logic.jumpTo(
                                  res.first ?? state.dateTimeList.first);
                            }
                          },
                          icon: const Icon(Icons.calendar_month_rounded)),
                      Obx(() {
                        return PopupMenuButton(
                          offset: const Offset(0, 46),
                          icon: Icon(iconMap[state.mediaType.value]!),
                          itemBuilder: (context) {
                            return MediaType.values.map((type) {
                              return CheckedPopupMenuItem(
                                checked: state.mediaType.value == type,
                                onTap: () async {
                                  await logic.changeMediaType(type);
                                },
                                child: Text(textMap[type]!),
                              );
                            }).toList();
                          },
                        );
                      }),
                      PopupMenuButton(
                        offset: const Offset(0, 46),
                        itemBuilder: (context) {
                          return [
                            PopupMenuItem(
                              onTap: () async {
                                await logic.cleanFile();
                              },
                              child: Row(
                                spacing: 16.0,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.delete_sweep),
                                  Text(l10n.mediaDeleteUseLessFile)
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: state.isFetching
                          ? const Center(
                              key: ValueKey('searching'),
                              child: SearchLoading())
                          : (state.datetimeMediaMap.isNotEmpty
                              ? ScrollablePositionedList.builder(
                                  itemBuilder: (context, index) {
                                    final datetime = state.dateTimeList[index];
                                    final fileList =
                                        state.datetimeMediaMap[datetime]!;
                                    return switch (state.mediaType.value) {
                                      MediaType.image => MediaImageComponent(
                                          dateTime: datetime,
                                          imageList: fileList),
                                      MediaType.audio => MediaAudioComponent(
                                          dateTime: datetime,
                                          audioList: fileList),
                                      MediaType.video => MediaVideoComponent(
                                          dateTime: datetime,
                                          videoList: fileList),
                                    };
                                  },
                                  padding: const EdgeInsets.all(4.0),
                                  itemCount: state.dateTimeList.length,
                                  itemScrollController:
                                      logic.itemScrollController,
                                  itemPositionsListener:
                                      logic.itemPositionsListener,
                                  scrollOffsetController:
                                      logic.scrollOffsetController,
                                  scrollOffsetListener:
                                      logic.scrollOffsetListener,
                                )
                              : const Center(
                                  key: ValueKey('empty'),
                                  child: FaIcon(
                                    FontAwesomeIcons.boxArchive,
                                    size: 80,
                                  ),
                                )),
                    ),
                  ),
                ],
              ),
              GetBuilder<MediaLogic>(
                  id: 'modal',
                  builder: (_) {
                    return state.isCleaning
                        ? const LottieModal(type: LoadingType.fileProcess)
                        : const SizedBox.shrink();
                  }),
            ],
          ),
        );
      },
    );
  }
}
