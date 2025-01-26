import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/common/values/icons.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/markdown_embed/image_embed.dart';
import 'package:moodiary/components/mood_icon/mood_icon_view.dart';
import 'package:moodiary/components/quill_embed/audio_embed.dart';
import 'package:moodiary/components/quill_embed/image_embed.dart';
import 'package:moodiary/components/quill_embed/text_indent.dart';
import 'package:moodiary/components/quill_embed/video_embed.dart';
import 'package:moodiary/main.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/theme_util.dart';
import 'package:refreshed/refreshed.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'diary_details_logic.dart';

class DiaryDetailsPage extends StatelessWidget {
  DiaryDetailsPage({super.key});

  final tag = (Get.arguments[0] as Diary).id;

  Widget _buildMarkdownWidget(
      {required Brightness brightness, required String data}) {
    final config = brightness == Brightness.dark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;
    return MarkdownBlock(
        data: data,
        config: config.copy(configs: [
          ImgConfig(builder: (src, _) {
            return MarkdownImageEmbed(isEdit: false, imageName: src);
          }),
          brightness == Brightness.dark
              ? PreConfig.darkConfig.copy(theme: a11yDarkTheme)
              : const PreConfig().copy(theme: a11yLightTheme)
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DiaryDetailsLogic>(tag: tag);
    final state = Bind.find<DiaryDetailsLogic>(tag: tag).state;
    final size = MediaQuery.sizeOf(context);
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildAChip(Widget label, Widget? avatar, ColorScheme colorScheme) {
      return Chip(
        label: label,
        avatar: avatar,
        side: BorderSide.none,
        backgroundColor: colorScheme.surface,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
      );
    }

    Widget buildChipList(ColorScheme colorScheme) {
      final dateTime =
          DateFormat.yMMMd().add_Hms().format(state.diary.time).split(' ');
      final date = dateTime.first;
      final time = dateTime.last;
      return Wrap(
        spacing: 8.0,
        children: [
          buildAChip(
              MoodIconComponent(value: state.diary.mood), null, colorScheme),
          buildAChip(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: textStyle.labelSmall!
                        .copyWith(color: colorScheme.onSurface),
                  ),
                  Text(
                    time,
                    style: textStyle.labelSmall!
                        .copyWith(color: colorScheme.onSurface),
                  )
                ],
              ),
              const Icon(Icons.access_time_outlined),
              colorScheme),
          if (state.diary.position.isNotEmpty) ...[
            buildAChip(Text(state.diary.position[2]),
                const Icon(Icons.location_city_rounded), colorScheme)
          ],
          if (state.diary.weather.isNotEmpty) ...[
            buildAChip(
                Text(
                  '${state.diary.weather[2]} ${state.diary.weather[1]}°C',
                  style: textStyle.labelLarge!
                      .copyWith(color: colorScheme.onSurface),
                ),
                Icon(
                  WeatherIcon.map[state.diary.weather[0]],
                ),
                colorScheme)
          ],
          buildAChip(
              Text(
                l10n.diaryCount(state.diary.contentText.length),
                style: textStyle.labelLarge!
                    .copyWith(color: colorScheme.onSurface),
              ),
              const Icon(
                Icons.text_fields_outlined,
              ),
              colorScheme),
          ...List.generate(state.diary.tags.length, (index) {
            return buildAChip(
                Text(
                  state.diary.tags[index],
                  style: textStyle.labelLarge!
                      .copyWith(color: colorScheme.onSurface),
                ),
                const Icon(
                  Icons.tag_outlined,
                ),
                colorScheme);
          })
        ],
      );
    }

    // List<Widget> buildMultiImages(colorScheme) {
    //   return List.generate(state.diary.imageName.length - 1, (index) {
    //     var actualIndex = index + 1; // 从第二个元素开始
    //     var imageProvider = FileImage(File(
    //         FileUtil.getRealPath('image', state.diary.imageName[actualIndex])));
    //     return Padding(
    //       padding: const EdgeInsets.all(4.0),
    //       child: InkWell(
    //         onTap: () {
    //           logic.toPhotoView(
    //               List.generate(state.diary.imageName.length, (index) {
    //                 return FileUtil.getRealPath(
    //                     'image', state.diary.imageName[index]);
    //               }),
    //               actualIndex);
    //         },
    //         borderRadius: AppBorderRadius.mediumBorderRadius,
    //         child: Container(
    //           width: ((size.width - 32) / 3).truncateToDouble(),
    //           height: ((size.width - 32) / 3).truncateToDouble(),
    //           constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
    //           decoration: BoxDecoration(
    //             borderRadius: AppBorderRadius.mediumBorderRadius,
    //             border: Border.all(
    //                 color: colorScheme.outline.withAlpha((255 * 0.8).toInt())),
    //             image: DecorationImage(
    //               image: imageProvider,
    //               fit: BoxFit.cover,
    //             ),
    //           ),
    //         ),
    //       ),
    //     );
    //   });
    // }

    // List<Widget> buildMultiVideo(colorScheme) {
    //   return List.generate(state.diary.videoName.length, (index) {
    //     var imageProvider = FileImage(File(FileUtil.getRealPath('video',
    //         'thumbnail-${state.diary.videoName[index].substring(6, 42)}.jpeg')));
    //     return Padding(
    //       padding: const EdgeInsets.all(4.0),
    //       child: InkWell(
    //         onTap: () {
    //           logic.toVideoView(
    //               List.generate(state.diary.videoName.length, (index) {
    //                 return FileUtil.getRealPath(
    //                     'video', state.diary.videoName[index]);
    //               }),
    //               index);
    //         },
    //         borderRadius: AppBorderRadius.mediumBorderRadius,
    //         child: Container(
    //           width: ((size.width - 32) / 3).truncateToDouble(),
    //           height: ((size.width - 32) / 3).truncateToDouble(),
    //           constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
    //           decoration: BoxDecoration(
    //             borderRadius: AppBorderRadius.mediumBorderRadius,
    //             border: Border.all(
    //                 color: colorScheme.outline.withAlpha((255 * 0.8).toInt())),
    //             image: DecorationImage(
    //               image: imageProvider,
    //               fit: BoxFit.cover,
    //             ),
    //           ),
    //           child: const Center(
    //             child: FaIcon(FontAwesomeIcons.video),
    //           ),
    //         ),
    //       ),
    //     );
    //   });
    // }

    // Widget buildAudioList() {
    //   return Wrap(
    //     children: [
    //       ...List.generate(state.diary.audioName.length, (index) {
    //         return AudioPlayerComponent(
    //             path: FileUtil.getRealPath(
    //                 'audio', state.diary.audioName[index]));
    //       })
    //     ],
    //   );
    // }

    // Widget buildCoverImage() {
    //   return InkWell(
    //     onTap: () {
    //       logic.toPhotoView(
    //           List.generate(state.diary.imageName.length, (index) {
    //             return FileUtil.getRealPath(
    //                 'image', state.diary.imageName[index]);
    //           }),
    //           0);
    //     },
    //     child: Image.file(
    //       File(FileUtil.getRealPath('image', state.diary.imageName.first)),
    //       fit: BoxFit.cover,
    //     ),
    //   );
    // }

    Widget buildImageView(ColorScheme colorScheme) {
      return Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: logic.pageController,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  logic.toPhotoView(
                    List.generate(state.diary.imageName.length, (i) {
                      return FileUtil.getRealPath(
                          'image', state.diary.imageName[i]);
                    }),
                    index,
                  );
                },
                child: Image.file(
                  File(FileUtil.getRealPath(
                      'image', state.diary.imageName[index])),
                  fit: BoxFit.cover,
                ),
              );
            },
            itemCount: state.diary.imageName.length,
          ),
          Positioned(
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: ShapeDecoration(
                    shape: const StadiumBorder(side: BorderSide.none),
                    color: colorScheme.surfaceContainer.withAlpha(100)),
                padding: state.diary.imageName.length > 9
                    ? const EdgeInsets.fromLTRB(6.0, 2.0, 6.0, 2.0)
                    : const EdgeInsets.all(2.0),
                child: SmoothPageIndicator(
                  controller: logic.pageController,
                  count: state.diary.imageName.length,
                  effect: state.diary.imageName.length > 9
                      ? ScrollingDotsEffect(
                          activeDotColor: colorScheme.tertiary,
                          dotColor:
                              colorScheme.surfaceContainerLow.withAlpha(200),
                          dotWidth: 8,
                          dotHeight: 8,
                          maxVisibleDots: 9)
                      : WormEffect(
                          activeDotColor: colorScheme.tertiary,
                          dotColor:
                              colorScheme.surfaceContainerLow.withAlpha(200),
                          dotWidth: 8,
                          dotHeight: 8,
                        ),
                  onDotClicked: logic.jumpToPage,
                ),
              ),
            ),
          )
        ],
      );
    }

    return GetBuilder<DiaryDetailsLogic>(
        tag: state.diary.id,
        builder: (_) {
          final customColorScheme = (state.imageColor != null &&
                  PrefUtil.getValue<bool>('dynamicColor') == true)
              ? ColorScheme.fromSeed(
                  seedColor: Color(state.imageColor!),
                  brightness: colorScheme.brightness,
                )
              : colorScheme;
          return Theme(
            data: Theme.of(context).copyWith(colorScheme: customColorScheme),
            child: Scaffold(
              backgroundColor: customColorScheme.surface,
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: state.diaryHeader
                        ? (state.aspect != null
                            ? min(
                                size.width / state.aspect!, size.height * 0.382)
                            : null)
                        : null,
                    title: Text(
                      state.diary.title,
                      style: textStyle.titleMedium,
                    ),
                    leading: const PageBackButton(),
                    centerTitle: false,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: state.diaryHeader
                          ? (state.diary.imageName.isNotEmpty
                              ? buildImageView(customColorScheme)
                              : null)
                          : null,
                    ),
                    pinned: true,
                    actions: [
                      // IconButton(
                      //     onPressed: () {
                      //       showModalBottomSheet(
                      //           context: context,
                      //           useSafeArea: true,
                      //           showDragHandle: true,
                      //           builder: (context) {
                      //             return Padding(
                      //               padding: MediaQuery.viewInsetsOf(context),
                      //               child: AskQuestionComponent(
                      //                 content: state.diary.contentText,
                      //               ),
                      //             );
                      //           });
                      //     },
                      //     icon: const Icon(Icons.chat)),
                      PopupMenuButton(
                        offset: const Offset(0, 46),
                        itemBuilder: (context) {
                          return <PopupMenuEntry<String>>[
                            if (state.showAction) ...[
                              PopupMenuItem(
                                onTap: () async {
                                  logic.delete(state.diary);
                                },
                                child: Row(
                                  spacing: 16.0,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.delete_rounded),
                                    Text(l10n.diaryDelete)
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                onTap: () async {
                                  logic.toEditPage(state.diary);
                                },
                                child: Row(
                                  spacing: 16.0,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.edit_rounded),
                                    Text(l10n.diaryEdit)
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                            ],
                            PopupMenuItem(
                              onTap: () async {
                                logic.toSharePage();
                              },
                              child: Row(
                                spacing: 16.0,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.share_rounded),
                                  Text(l10n.diaryShare)
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(4.0),
                    sliver: SliverList.list(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: buildChipList(customColorScheme)),
                        ),
                        Card.filled(
                          color: customColorScheme.surfaceContainerLow,
                          child: state.diary.type == DiaryType.markdown.value
                              ? Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _buildMarkdownWidget(
                                      brightness: customColorScheme.brightness,
                                      data: state.diary.content),
                                )
                              : QuillEditor.basic(
                                  controller: logic.quillController!,
                                  config: QuillEditorConfig(
                                    showCursor: false,
                                    padding: const EdgeInsets.all(8.0),
                                    customStyles: ThemeUtil.getInstance(context,
                                        customColorScheme: customColorScheme),
                                    embedBuilders: [
                                      ImageEmbedBuilder(isEdit: false),
                                      VideoEmbedBuilder(isEdit: false),
                                      AudioEmbedBuilder(isEdit: false),
                                      TextIndentEmbedBuilder(isEdit: false),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}
