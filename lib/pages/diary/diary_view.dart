import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/values/icons.dart';
import 'package:mood_diary/components/audio_player/audio_player_view.dart';
import 'package:mood_diary/components/mood_icon/mood_icon_view.dart';
import 'package:mood_diary/utils/utils.dart';

import 'diary_logic.dart';

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DiaryLogic>();
    final state = Bind.find<DiaryLogic>().state;
    final size = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    var imageColor = state.diary.imageColor;
    final colorScheme = imageColor != null
        ? ColorScheme.fromSeed(
            seedColor: Color(imageColor),
            brightness: Theme.of(context).brightness,
          )
        : Theme.of(context).colorScheme;
    Widget buildChipList() {
      return Wrap(
        spacing: 8.0,
        children: [
          Chip(
            label: MoodIconComponent(value: state.diary.mood),
            backgroundColor: colorScheme.secondaryContainer,
            side: BorderSide.none,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.zero,
          ),
          Chip(
            label: Text(
              DateFormat.yMMMd().add_Hms().format(state.diary.time),
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
            avatar: const Icon(Icons.access_time_outlined),
            iconTheme: IconThemeData(color: colorScheme.secondary),
            backgroundColor: colorScheme.secondaryContainer,
            side: BorderSide.none,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.only(right: 8),
          ),
          if (state.diary.weather.isNotEmpty) ...[
            Chip(
              label: Text(
                '${state.diary.weather[2]} ${state.diary.weather[1]}°C',
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
              avatar: Icon(
                WeatherIcon.map[state.diary.weather[0]],
                color: colorScheme.primary,
              ),
              iconTheme: IconThemeData(color: colorScheme.secondary),
              backgroundColor: colorScheme.secondaryContainer,
              side: BorderSide.none,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.only(right: 8),
            )
          ],
          Chip(
            label: Text(
              '${state.diary.contentText.length} 字',
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
            avatar: Icon(
              Icons.text_fields_outlined,
              color: colorScheme.primary,
            ),
            iconTheme: IconThemeData(color: colorScheme.secondary),
            backgroundColor: colorScheme.secondaryContainer,
            side: BorderSide.none,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.only(right: 8),
          ),
          ...List.generate(state.diary.tags.length, (index) {
            return Chip(
              label: Text(
                state.diary.tags[index],
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
              avatar: Icon(
                Icons.tag_outlined,
                color: colorScheme.primary,
              ),
              iconTheme: IconThemeData(color: colorScheme.secondary),
              backgroundColor: colorScheme.secondaryContainer,
              side: BorderSide.none,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.only(right: 8),
            );
          })
        ],
      );
    }

    List<Widget> buildMultiImages() {
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
              borderRadius: const BorderRadius.all(Radius.circular(8.0)),
              border: Border.all(color: colorScheme.outline.withOpacity(0.8)),
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

    return GetBuilder<DiaryLogic>(
      assignId: true,
      init: logic,
      builder: (logic) {
        var imageColor = state.diary.imageColor;
        return Theme(
          data: imageColor != null
              ? Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Color(imageColor),
                    brightness: Theme.of(context).brightness,
                  ),
                )
              : Theme.of(context),
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: state.diary.aspect != null
                      ? min(size.width / state.diary.aspect!, size.height - viewPadding.top)
                      : null,
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
                          logic.delete(state.diary);
                        },
                        icon: const Icon(Icons.delete)),
                    IconButton(
                        onPressed: () {
                          logic.toEditPage(state.diary);
                        },
                        icon: const Icon(Icons.edit)),
                    IconButton(
                      onPressed: () {
                        logic.toSharePage();
                      },
                      icon: const Icon(Icons.share),
                    ),
                  ],
                ),
                SliverList.list(children: [
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8.0), child: buildChipList()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: const BorderRadius.all(Radius.circular(8.0))),
                      child: QuillEditor.basic(
                        controller: logic.quillController,
                        configurations: const QuillEditorConfigurations(
                          showCursor: false,
                          sharedConfigurations: QuillSharedConfigurations(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  //绘制图片
                  if (state.diary.imageName.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: buildMultiImages(),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                  ],
                  if (state.diary.audioName.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: buildAudioList(),
                    ),
                    const SizedBox(height: 8.0),
                  ]
                ])
              ],
            ),
          ),
        );
      },
    );
  }
}
