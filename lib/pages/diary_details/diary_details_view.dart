import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/icons.dart';
import 'package:mood_diary/components/ask_question/ask_question_view.dart';
import 'package:mood_diary/components/audio_player/audio_player_view.dart';
import 'package:mood_diary/components/mood_icon/mood_icon_view.dart';
import 'package:mood_diary/utils/utils.dart';

import 'diary_details_logic.dart';

class DiaryDetailsPage extends StatelessWidget {
  const DiaryDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DiaryDetailsLogic>();
    final state = Bind.find<DiaryDetailsLogic>().state;
    final size = MediaQuery.sizeOf(context);
    final textStyle = Theme.of(context).textTheme;

    Widget buildAChip(Widget label, Widget? avatar, ColorScheme colorScheme) {
      return Chip(
        label: label,
        avatar: avatar,
        side: BorderSide.none,
        backgroundColor: colorScheme.secondaryContainer,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        labelPadding: avatar == null ? EdgeInsets.zero : const EdgeInsets.only(right: 8),
      );
    }

    Widget buildChipList(ColorScheme colorScheme) {
      return Wrap(
        spacing: 8.0,
        children: [
          buildAChip(MoodIconComponent(value: state.diary.mood), null, colorScheme),
          buildAChip(
              Text(
                DateFormat.yMMMd().add_Hms().format(state.diary.time),
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
              const Icon(Icons.access_time_outlined),
              colorScheme),
          if (state.diary.weather.isNotEmpty) ...[
            buildAChip(
                Text(
                  '${state.diary.weather[2]} ${state.diary.weather[1]}°C',
                ),
                Icon(
                  WeatherIcon.map[state.diary.weather[0]],
                ),
                colorScheme)
          ],
          buildAChip(
              Text(
                '${state.diary.contentText.length} 字',
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
              const Icon(
                Icons.text_fields_outlined,
              ),
              colorScheme),
          ...List.generate(state.diary.tags.length, (index) {
            return buildAChip(
                Text(
                  state.diary.tags[index],
                  style: TextStyle(color: colorScheme.onSecondaryContainer),
                ),
                const Icon(
                  Icons.tag_outlined,
                ),
                colorScheme);
          })
        ],
      );
    }

    List<Widget> buildMultiImages(colorScheme) {
      return List.generate(state.diary.imageName.length - 1, (index) {
        var actualIndex = index + 1; // 从第二个元素开始
        var imageProvider = FileImage(File(Utils().fileUtil.getRealPath('image', state.diary.imageName[actualIndex])));
        return InkWell(
          onTap: () {
            logic.toPhotoView(state.diary.imageName, actualIndex);
          },
          child: Container(
            width: ((size.width - 32) / 3).truncateToDouble(),
            height: ((size.width - 32) / 3).truncateToDouble(),
            constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.smallBorderRadius,
              border: Border.all(color: colorScheme.outline.withAlpha((255 * 0.8).toInt())),
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      });
    }

    Widget buildAudioList() {
      return Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          ...List.generate(state.diary.audioName.length, (index) {
            return AudioPlayerComponent(
                path: Utils().fileUtil.getRealPath('audio', state.diary.audioName[index]), index: index.toString());
          })
        ],
      );
    }

    return GetBuilder<DiaryDetailsLogic>(
      assignId: true,
      init: logic,
      builder: (logic) {
        var imageColor = state.diary.imageColor;
        final colorScheme = imageColor != null
            ? ColorScheme.fromSeed(
                seedColor: Color(imageColor),
                brightness: Theme.of(context).brightness,
              )
            : Theme.of(context).colorScheme;
        var aspect = state.diary.aspect;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme,
          ),
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: aspect != null
                      ? (aspect <= 1.0 ? min(size.width / aspect, size.height * 0.618) : size.width / aspect)
                      : null,
                  title: Text(
                    state.diary.title ?? '',
                    style: textStyle.titleMedium,
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: state.diary.imageName.isNotEmpty
                        ? InkWell(
                            onTap: () {
                              logic.toPhotoView(state.diary.imageName, 0);
                            },
                            child: Image.file(
                              File(Utils().fileUtil.getRealPath('image', state.diary.imageName.first)),
                              fit: BoxFit.cover,
                            ),
                          )
                        : null,
                  ),
                  pinned: true,
                  actions: [
                    IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                              context: context,
                              useSafeArea: true,
                              showDragHandle: true,
                              builder: (context) {
                                return Padding(
                                  padding: MediaQuery.viewInsetsOf(context),
                                  child: AskQuestionComponent(
                                    content: state.diary.contentText,
                                  ),
                                );
                              });
                        },
                        icon: const Icon(Icons.chat)),
                    PopupMenuButton(
                      offset: const Offset(0, 46),
                      itemBuilder: (context) {
                        return <PopupMenuEntry<String>>[
                          if (state.showAction) ...[
                            PopupMenuItem(
                              onTap: () async {
                                logic.delete(state.diary);
                              },
                              child: const Row(
                                spacing: 16.0,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [Icon(Icons.delete), Text('删除')],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              onTap: () async {
                                logic.toEditPage(state.diary);
                              },
                              child: const Row(
                                spacing: 16.0,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [Icon(Icons.edit), Text('编辑')],
                              ),
                            ),
                            const PopupMenuDivider(),
                          ],
                          PopupMenuItem(
                            onTap: () async {
                              logic.toSharePage();
                            },
                            child: const Row(
                              spacing: 16.0,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [Icon(Icons.share), Text('分享')],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      spacing: 8.0,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(scrollDirection: Axis.horizontal, child: buildChipList(colorScheme)),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                              color: colorScheme.surfaceContainer, borderRadius: AppBorderRadius.smallBorderRadius),
                          child: QuillEditor.basic(
                            controller: logic.quillController,
                            configurations: const QuillEditorConfigurations(
                              showCursor: false,
                              sharedConfigurations: QuillSharedConfigurations(),
                            ),
                          ),
                        ),
                        //绘制图片
                        if (state.diary.imageName.length > 1) ...[
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: buildMultiImages(colorScheme),
                          ),
                        ],
                        if (state.diary.audioName.isNotEmpty) ...[
                          buildAudioList(),
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
