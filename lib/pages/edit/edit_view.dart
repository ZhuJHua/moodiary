import 'dart:io';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/colors.dart';
import 'package:mood_diary/components/base/sheet.dart';
import 'package:mood_diary/components/category_add/category_add_view.dart';
import 'package:mood_diary/components/expand_button/expand_button_view.dart';
import 'package:mood_diary/components/lottie_modal/lottie_modal.dart';
import 'package:mood_diary/components/mood_icon/mood_icon_view.dart';
import 'package:mood_diary/components/quill_embed/image_embed.dart';
import 'package:mood_diary/components/quill_embed/text_indent.dart';
import 'package:mood_diary/components/quill_embed/video_embed.dart';
import 'package:mood_diary/components/record_sheet/record_sheet_view.dart';
import 'package:mood_diary/utils/theme_util.dart';

import '../../common/values/diary_type.dart';
import '../../components/quill_embed/audio_embed.dart';
import 'edit_logic.dart';

class EditPage extends StatelessWidget {
  const EditPage({super.key});

  _buildToolBarButton({
    required IconData iconData,
    required String tooltip,
    required Function() onPressed,
  }) {
    return IconButton(
      icon: Icon(
        iconData,
        size: 24,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<EditLogic>();
    final state = Bind
        .find<EditLogic>()
        .state;
    final colorScheme = Theme
        .of(context)
        .colorScheme;

    final textStyle = Theme
        .of(context)
        .textTheme;

    // Widget buildAddContainer(Widget icon) {
    //   return Container(
    //     decoration: BoxDecoration(
    //       borderRadius: AppBorderRadius.smallBorderRadius,
    //       color: colorScheme.surfaceContainerHighest,
    //     ),
    //     constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
    //     width: ((size.width - 56.0) / 3).truncateToDouble(),
    //     height: ((size.width - 56.0) / 3).truncateToDouble(),
    //     child: Center(child: icon),
    //   );
    // }

    //标签列表
    Widget? buildTagList() {
      return state.currentDiary.tags.isNotEmpty
          ? Wrap(
        spacing: 8.0,
        children: List.generate(state.currentDiary.tags.length, (index) {
          return Chip(
            label: Text(
              state.currentDiary.tags[index],
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
            backgroundColor: colorScheme.secondaryContainer,
            onDeleted: () {
              logic.removeTag(index);
            },
          );
        }),
      )
          : null;
    }

    // Widget buildAudioPlayer() {
    //   return Wrap(
    //     children: [
    //       ...List.generate(state.audioNameList.length, (index) {
    //         return AudioPlayerComponent(
    //             path: FileUtil.getCachePath(state.audioNameList[index]));
    //       }),
    //       ActionChip(
    //         label: const Text('添加'),
    //         avatar: const Icon(Icons.add),
    //         onPressed: () {
    //           showModalBottomSheet(
    //               context: context,
    //               showDragHandle: true,
    //               useSafeArea: true,
    //               isScrollControlled: true,
    //               builder: (context) {
    //                 return const RecordSheetComponent();
    //               });
    //         },
    //       )
    //     ],
    //   );
    // }

    // Widget buildImage() {
    //   return Padding(
    //     padding: const EdgeInsets.only(top: 8.0),
    //     child: Wrap(
    //       spacing: 8.0,
    //       runSpacing: 8.0,
    //       children: [
    //         ...List.generate(state.imageFileList.length, (index) {
    //           return InkWell(
    //             borderRadius: AppBorderRadius.smallBorderRadius,
    //             onLongPress: () {
    //               logic.setCover(index);
    //             },
    //             onTap: () {
    //               logic.toPhotoView(
    //                   List.generate(state.imageFileList.length, (index) {
    //                     return state.imageFileList[index].path;
    //                   }),
    //                   index);
    //             },
    //             child: Container(
    //               constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
    //               width: ((size.width - 56.0) / 3).truncateToDouble(),
    //               height: ((size.width - 56.0) / 3).truncateToDouble(),
    //               padding: const EdgeInsets.all(2.0),
    //               decoration: BoxDecoration(
    //                 borderRadius: AppBorderRadius.smallBorderRadius,
    //                 border: Border.all(color: colorScheme.outline.withAlpha((255 * 0.5).toInt())),
    //                 image: DecorationImage(
    //                   image: FileImage(File(state.imageFileList[index].path)),
    //                   fit: BoxFit.cover,
    //                 ),
    //               ),
    //               child: Row(
    //                 mainAxisSize: MainAxisSize.min,
    //                 mainAxisAlignment: MainAxisAlignment.end,
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Container(
    //                     decoration: BoxDecoration(
    //                       color: colorScheme.surface.withAlpha((255 * 0.5).toInt()),
    //                       borderRadius: AppBorderRadius.smallBorderRadius,
    //                     ),
    //                     child: IconButton(
    //                       onPressed: () {
    //                         showDialog(
    //                             context: context,
    //                             builder: (context) {
    //                               return AlertDialog(
    //                                 title: const Text('提示'),
    //                                 content: const Text('确认删除这张照片吗'),
    //                                 actions: [
    //                                   TextButton(
    //                                       onPressed: () {
    //                                         Get.backLegacy();
    //                                       },
    //                                       child: const Text('取消')),
    //                                   TextButton(
    //                                       onPressed: () {
    //                                         logic.deleteImage(index);
    //                                       },
    //                                       child: const Text('确认'))
    //                                 ],
    //                               );
    //                             });
    //                       },
    //                       constraints: const BoxConstraints(),
    //                       icon: Icon(
    //                         Icons.remove_circle_outlined,
    //                         color: colorScheme.tertiary,
    //                       ),
    //                       style: IconButton.styleFrom(
    //                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    //                         padding: const EdgeInsets.all(4.0),
    //                       ),
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //           );
    //         }),
    //         ...[
    //           InkWell(
    //             borderRadius: AppBorderRadius.smallBorderRadius,
    //             onTap: () {
    //               showDialog(
    //                   context: context,
    //                   builder: (context) {
    //                     return SimpleDialog(
    //                       title: const Text('选择来源'),
    //                       children: [
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.photo_library_outlined),
    //                               Text('相册'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.pickMultiPhoto();
    //                           },
    //                         ),
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.camera_alt_outlined),
    //                               Text('相机'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.pickPhoto(ImageSource.camera);
    //                           },
    //                         ),
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.image_search_outlined),
    //                               Text('网络'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.networkImage();
    //                           },
    //                         ),
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.draw_outlined),
    //                               Text('画画'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.toDrawPage();
    //                           },
    //                         ),
    //                       ],
    //                     );
    //                   });
    //             },
    //             child: buildAddContainer(const FaIcon(FontAwesomeIcons.image)),
    //           )
    //         ],
    //       ],
    //     ),
    //   );
    // }

    // Widget buildVideo() {
    //   return Padding(
    //     padding: const EdgeInsets.only(top: 8.0),
    //     child: Wrap(
    //       spacing: 8.0,
    //       runSpacing: 8.0,
    //       children: [
    //         ...List.generate(state.videoFileList.length, (index) {
    //           return InkWell(
    //             onTap: () {
    //               logic.toVideoView(
    //                   List.generate(state.videoFileList.length, (index) {
    //                     return state.videoFileList[index].path;
    //                   }),
    //                   index);
    //             },
    //             child: Container(
    //               constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
    //               width: ((size.width - 56.0) / 3).truncateToDouble(),
    //               height: ((size.width - 56.0) / 3).truncateToDouble(),
    //               padding: const EdgeInsets.all(2.0),
    //               decoration: BoxDecoration(
    //                   borderRadius: AppBorderRadius.smallBorderRadius,
    //                   border: Border.all(color: colorScheme.outline.withAlpha((255 * 0.5).toInt())),
    //                   image: DecorationImage(
    //                     image: FileImage(File(state.videoThumbnailFileList[index].path)),
    //                     fit: BoxFit.cover,
    //                   )),
    //               child: Row(
    //                 mainAxisSize: MainAxisSize.min,
    //                 mainAxisAlignment: MainAxisAlignment.end,
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Container(
    //                     decoration: BoxDecoration(
    //                       color: colorScheme.surface.withAlpha((255 * 0.5).toInt()),
    //                       borderRadius: AppBorderRadius.smallBorderRadius,
    //                     ),
    //                     child: IconButton(
    //                       onPressed: () {
    //                         showDialog(
    //                             context: context,
    //                             builder: (context) {
    //                               return AlertDialog(
    //                                 title: const Text('提示'),
    //                                 content: const Text('确认删除这个视频吗'),
    //                                 actions: [
    //                                   TextButton(
    //                                       onPressed: () {
    //                                         Get.backLegacy();
    //                                       },
    //                                       child: const Text('取消')),
    //                                   TextButton(
    //                                       onPressed: () {
    //                                         logic.deleteVideo(index);
    //                                       },
    //                                       child: const Text('确认'))
    //                                 ],
    //                               );
    //                             });
    //                       },
    //                       constraints: const BoxConstraints(),
    //                       icon: Icon(
    //                         Icons.remove_circle_outlined,
    //                         color: colorScheme.tertiary,
    //                       ),
    //                       style: IconButton.styleFrom(
    //                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    //                         padding: const EdgeInsets.all(4.0),
    //                       ),
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //           );
    //         }),
    //         if (state.videoFileList.length < 9) ...[
    //           InkWell(
    //             borderRadius: AppBorderRadius.smallBorderRadius,
    //             onTap: () {
    //               showDialog(
    //                   context: context,
    //                   builder: (context) {
    //                     return SimpleDialog(
    //                       title: const Text('选择来源'),
    //                       children: [
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.photo_library_outlined),
    //                               Text('相册'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.pickVideo(ImageSource.gallery);
    //                           },
    //                         ),
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.camera_alt_outlined),
    //                               Text('拍摄'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.pickVideo(ImageSource.camera);
    //                           },
    //                         ),
    //                       ],
    //                     );
    //                   });
    //             },
    //             child: buildAddContainer(const FaIcon(FontAwesomeIcons.video)),
    //           )
    //         ],
    //       ],
    //     ),
    //   );
    // }

    Widget buildMoodSlider() {
      return Container(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            MoodIconComponent(value: state.currentDiary.mood),
            Expanded(
              child: Slider(
                  value: state.currentDiary.mood,
                  divisions: 10,
                  label:
                  '${(state.currentDiary.mood * 100).toStringAsFixed(0)}%',
                  activeColor: Color.lerp(AppColor.emoColorList.first,
                      AppColor.emoColorList.last, state.currentDiary.mood),
                  onChanged: (value) {
                    logic.changeRate(value);
                  }),
            ),
          ],
        ),
      );
    }

    Widget buildPickImage() {
      return SimpleDialog(
        title: const Text('选择来源'),
        children: [
          SimpleDialogOption(
            child: const Row(
              spacing: 8.0,
              children: [
                Icon(Icons.photo_library_outlined),
                Text('相册'),
              ],
            ),
            onPressed: () async {
              await logic.pickPhoto(ImageSource.gallery);
            },
          ),
          if (Platform.isAndroid || Platform.isIOS)
            SimpleDialogOption(
              child: const Row(
                spacing: 8.0,
                children: [
                  Icon(Icons.camera_alt_outlined),
                  Text('相机'),
                ],
              ),
              onPressed: () async {
                await logic.pickPhoto(ImageSource.camera);
              },
            ),
          SimpleDialogOption(
            child: const Row(
              spacing: 8.0,
              children: [
                Icon(Icons.image_search_outlined),
                Text('网络'),
              ],
            ),
            onPressed: () async {
              await logic.networkImage();
            },
          ),
          SimpleDialogOption(
            child: const Row(
              spacing: 8.0,
              children: [
                Icon(Icons.draw_outlined),
                Text('画画'),
              ],
            ),
            onPressed: () {
              logic.toDrawPage();
            },
          ),
        ],
      );
    }

    Widget buildPickVideo() {
      return SimpleDialog(
        title: const Text('选择来源'),
        children: [
          SimpleDialogOption(
            child: const Row(
              spacing: 8.0,
              children: [
                Icon(Icons.photo_library_outlined),
                Text('相册'),
              ],
            ),
            onPressed: () async {
              await logic.pickVideo(ImageSource.gallery);
            },
          ),
          if (Platform.isAndroid || Platform.isIOS)
            SimpleDialogOption(
              child: const Row(
                spacing: 8.0,
                children: [
                  Icon(Icons.camera_alt_outlined),
                  Text('拍摄'),
                ],
              ),
              onPressed: () async {
                await logic.pickVideo(ImageSource.camera);
              },
            ),
        ],
      );
    }

    Widget buildDetail() {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          ListTile(
            onTap: null,
            title: const Text('日期与时间'),
            subtitle: GetBuilder<EditLogic>(
                id: 'Date',
                builder: (_) {
                  return Text(state.currentDiary.time.toString().split('.')[0]);
                }),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  onPressed: () async {
                    await logic.changeDate();
                  },
                  icon: const Icon(Icons.date_range),
                ),
                IconButton.filledTonal(
                  onPressed: () async {
                    await logic.changeTime();
                  },
                  icon: const Icon(Icons.access_time),
                )
              ],
            ),
          ),
          GetBuilder<EditLogic>(
              id: 'Weather',
              builder: (_) {
                return ListTile(
                  title: const Text('天气'),
                  subtitle: state.currentDiary.weather.isNotEmpty
                      ? Text(
                      '${state.currentDiary.weather[2]} ${state.currentDiary
                          .weather[1]}°C')
                      : null,
                  trailing: state.isProcessing
                      ? const CircularProgressIndicator()
                      : IconButton.filledTonal(
                    onPressed: () async {
                      await logic.getPositionAndWeather();
                    },
                    icon: const Icon(Icons.location_on),
                  ),
                );
              }),
          GetBuilder<EditLogic>(
              id: 'CategoryName',
              builder: (_) {
                return ListTile(
                  title: const Text('分类'),
                  subtitle: state.categoryName.isNotEmpty
                      ? Text(state.categoryName)
                      : null,
                  trailing: IconButton.filledTonal(
                    onPressed: () {
                      showFloatingModalBottomSheet(
                          context: context,
                          builder: (context) {
                            return const CategoryAddComponent();
                          });
                    },
                    icon: const Icon(Icons.category),
                  ),
                );
              }),
          GetBuilder<EditLogic>(
              id: 'Tag',
              builder: (_) {
                return ListTile(
                  title: const Text('标签'),
                  subtitle: buildTagList(),
                  trailing: IconButton.filledTonal(
                    icon: const Icon(Icons.tag),
                    onPressed: () async {
                      var res = await showTextInputDialog(
                        style: AdaptiveStyle.material,
                        context: context,
                        title: '添加标签',
                        textFields: [
                          const DialogTextField(
                            hintText: '标签',
                          )
                        ],
                      );
                      if (res != null && res.isNotEmpty) {
                        logic.addTag(tag: res.first);
                      }
                    },
                  ),
                );
              }),
          ListTile(
            title: const Text('心情指数'),
            subtitle: GetBuilder<EditLogic>(
                id: 'Mood',
                builder: (_) {
                  return buildMoodSlider();
                }),
          ),
          // ListTile(
          //   title: const Text('图片'),
          //   subtitle: GetBuilder<EditLogic>(
          //       id: 'Image',
          //       builder: (_) {
          //         return buildImage();
          //       }),
          // ),
          // ListTile(
          //   title: const Text('视频'),
          //   subtitle: GetBuilder<EditLogic>(
          //       id: 'Video',
          //       builder: (_) {
          //         return buildVideo();
          //       }),
          // ),
          // ListTile(
          //   title: const Text('音频'),
          //   subtitle: GetBuilder<EditLogic>(
          //       id: 'Audio',
          //       builder: (_) {
          //         return buildAudioPlayer();
          //       }),
          // ),
        ],
      );
    }

    Widget buildTimer() {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer.withValues(alpha: 0.8),
          borderRadius: AppBorderRadius.smallBorderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Obx(() {
          return RichText(
            text: TextSpan(
              text: '时间 ',
              style: textStyle.labelSmall,
              children: [
                TextSpan(
                  text: state.durationString.value.toString(),
                  style: textStyle.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontFeatures: [const FontFeature.tabularFigures()]),
                ),
              ],
            ),
          );
        }),
      );
    }

    Widget buildCount() {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer.withValues(alpha: 0.8),
          borderRadius: AppBorderRadius.smallBorderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Obx(() {
          return RichText(
            text: TextSpan(
              text: '字数 ',
              style: textStyle.labelSmall,
              children: [
                TextSpan(
                  text: state.totalCount.value.toString(),
                  style: textStyle.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontFeatures: [const FontFeature.tabularFigures()]),
                ),
              ],
            ),
          );
        }),
      );
    }

    Widget buildTitle() {
      return AutoSizeTextField(
        controller: logic.titleTextEditingController,
        focusNode: logic.titleFocusNode,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: textStyle.titleLarge!.copyWith(fontWeight: FontWeight.bold),
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          border: UnderlineInputBorder(borderSide: BorderSide.none),
          hintText: '标题',
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
        ),
      );
    }

    Widget buildToolBar() {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: TooltipTheme(
          data: const TooltipThemeData(preferBelow: false),
          child: QuillSimpleToolbar(
            controller: logic.quillController,
            config: QuillSimpleToolbarConfig(
              showFontFamily: false,
              showFontSize: false,
              showBackgroundColorButton: true,
              showAlignmentButtons: true,
              showClipboardPaste: false,
              showClipboardCut: false,
              showClipboardCopy: false,
              showIndent: false,
              showDividers: false,
              multiRowsDisplay: false,
              headerStyleType: HeaderStyleType.buttons,
              buttonOptions: QuillSimpleToolbarButtonOptions(
                  selectHeaderStyleButtons:
                  QuillToolbarSelectHeaderStyleButtonsOptions(
                    iconTheme: QuillIconTheme(iconButtonSelectedData:IconButtonData(
                      color: colorScheme.onPrimary,
                    )),)
              ),
              showLink: false,
              embedButtons: [
                    (context, embedContext) {
                  return _buildToolBarButton(
                    iconData: Icons.format_indent_increase,
                    tooltip: 'Text Indent',
                    onPressed: logic.insertNewLine,
                  );
                },
              ],
            ),
          ),
        ),
      );
    }

    Widget richTextToolBar() {
      return Row(
        children: [
          ExpandButtonComponent(operatorMap: {
            Icons.keyboard_command_key: () {
              showFloatingModalBottomSheet(
                context: context,
                builder: (context) {
                  return buildDetail();
                },
              );
            },
            Icons.image_rounded: () {
              showDialog(
                context: context,
                builder: (context) {
                  return buildPickImage();
                },
              );
            },
            Icons.movie_rounded: () {
              showDialog(
                context: context,
                builder: (context) {
                  return buildPickVideo();
                },
              );
            },
            Icons.audiotrack_rounded: () {
              showFloatingModalBottomSheet(
                context: context,
                builder: (context) {
                  return const RecordSheetComponent();
                },
              );
            }
          }),
          Expanded(
            child: buildToolBar(),
          ),
        ],
      );
    }

    Widget textToolBar() {
      return Row(
        children: [
          IconButton.filled(
            icon: const Icon(Icons.keyboard_command_key),
            style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: () {
              showFloatingModalBottomSheet(
                context: context,
                builder: (context) {
                  return buildDetail();
                },
              );
            },
          ),
          Expanded(child: buildToolBar()),
        ],
      );
    }

    Widget buildWriting() {
      return Column(
        children: [
          Flexible(
            child: Stack(
              alignment: Alignment.center,
              children: [
                QuillEditor.basic(
                  focusNode: logic.contentFocusNode,
                  controller: logic.quillController,
                  config: QuillEditorConfig(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    placeholder: '正文',
                    expands: true,
                    paintCursorAboveText: true,
                    keyboardAppearance:
                    CupertinoTheme.maybeBrightnessOf(context) ??
                        Theme
                            .of(context)
                            .brightness,
                    customStyles: ThemeUtil.getInstance(context,
                        customColorScheme: colorScheme),
                    embedBuilders: [
                      if (state.type == DiaryType.richText) ...[
                        ImageEmbedBuilder(isEdit: true),
                        VideoEmbedBuilder(isEdit: true),
                        AudioEmbedBuilder(isEdit: true),
                      ],
                      TextIndentEmbedBuilder(isEdit: true),
                    ],
                  ),
                ),
                Positioned(
                    top: 2,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8.0,
                      children: [
                        if (state.showWriteTime) buildTimer(),
                        if (state.showWordCount) buildCount(),
                      ],
                    )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: switch (state.type) {
              DiaryType.text => textToolBar(),
              DiaryType.richText => richTextToolBar(),
            },
          )
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (canPop, _) {
        if (canPop) return;
        logic.handleBack();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          GetBuilder<EditLogic>(
              id: 'body',
              builder: (_) {
                return Scaffold(
                  appBar: AppBar(
                    title: buildTitle(),
                    titleSpacing: .0,
                    centerTitle: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          logic.unFocus();
                          logic.saveDiary();
                        },
                        tooltip: '保存',
                      ),
                    ],
                  ),
                  body: SafeArea(
                      child: state.isInit
                          ? buildWriting()
                          : const Center(child: CircularProgressIndicator())),
                );
              }),
          GetBuilder<EditLogic>(
              id: 'modal',
              builder: (_) {
                return state.isSaving
                    ? const LottieModal(type: LoadingType.cat)
                    : const SizedBox.shrink();
              }),
        ],
      ),
    );
  }
}
