import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/colors.dart';
import 'package:mood_diary/components/audio_player/audio_player_view.dart';
import 'package:mood_diary/components/category_add/category_add_view.dart';
import 'package:mood_diary/components/keepalive/keepalive.dart';
import 'package:mood_diary/components/mood_icon/mood_icon_view.dart';
import 'package:mood_diary/components/record_sheet/record_sheet_view.dart';
import 'package:mood_diary/utils/utils.dart';

import 'edit_logic.dart';

class EditPage extends StatelessWidget {
  const EditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<EditLogic>();
    final state = Bind.find<EditLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final i18n = AppLocalizations.of(context)!;

    //标签列表
    Widget? buildTagList() {
      return state.tagList.isNotEmpty
          ? Wrap(
              spacing: 8.0,
              children: List.generate(state.tagList.length, (index) {
                return Chip(
                  label: Text(
                    state.tagList[index],
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

    Widget buildAudioPlayer() {
      return Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          ...List.generate(state.audioNameList.length, (index) {
            return AudioPlayerComponent(
              path: Utils().fileUtil.getCachePath(state.audioNameList[index]),
              index: index.toString(),
              isEdit: true,
            );
          }),
          ActionChip(
            label: const Text('添加'),
            avatar: const Icon(Icons.add),
            onPressed: () {
              showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (context) {
                    return const RecordSheetComponent();
                  });
            },
          )
        ],
      );
    }

    Widget buildImage() {
      return Wrap(
        spacing: 8.0,
        children: [
          ...List.generate(state.imageList.length, (index) {
            return InkWell(
              borderRadius: AppBorderRadius.smallBorderRadius,
              onLongPress: () {
                logic.setCover(index);
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
                width: ((size.width - 56.0) / 3).truncateToDouble(),
                height: ((size.width - 56.0) / 3).truncateToDouble(),
                padding: const EdgeInsets.all(2.0),
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                decoration: BoxDecoration(
                  borderRadius: AppBorderRadius.smallBorderRadius,
                  border: Border.all(color: colorScheme.outline.withAlpha((255 * 0.5).toInt())),
                  image: DecorationImage(
                    image: MemoryImage(state.imageList[index]),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withAlpha((255 * 0.5).toInt()),
                        borderRadius: AppBorderRadius.smallBorderRadius,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('提示'),
                                      content: const Text('确认删除这张照片吗'),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              Get.backLegacy();
                                            },
                                            child: const Text('取消')),
                                        TextButton(
                                            onPressed: () {
                                              logic.deleteImage(index);
                                            },
                                            child: const Text('确认'))
                                      ],
                                    );
                                  });
                            },
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.remove_circle_outlined,
                              color: colorScheme.tertiary,
                            ),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.all(4.0),
                            ),
                          ),
                          if (state.coverImageName == state.imageNameList[index]) ...[
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.stars,
                                color: colorScheme.primary,
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (state.imageList.length < 10) ...[
            InkWell(
              borderRadius: AppBorderRadius.smallBorderRadius,
              onTap: () {
                showDialog(
                    context: context,
                    builder: (context) {
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
                            onPressed: () {
                              logic.pickMultiPhoto();
                            },
                          ),
                          SimpleDialogOption(
                            child: const Row(
                              spacing: 8.0,
                              children: [
                                Icon(Icons.camera_alt_outlined),
                                Text('相机'),
                              ],
                            ),
                            onPressed: () {
                              logic.pickPhoto(ImageSource.camera);
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
                            onPressed: () {
                              logic.networkImage();
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
                    });
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppBorderRadius.smallBorderRadius,
                  color: colorScheme.surfaceContainerHighest,
                ),
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
                width: ((size.width - 56.0) / 3).truncateToDouble(),
                height: ((size.width - 56.0) / 3).truncateToDouble(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add),
                  ],
                ),
              ),
            )
          ],
        ],
      );
    }

    Widget buildDetail() {
      return ListView(
        children: [
          ListTile(
            onTap: null,
            title: const Text('日期与时间'),
            subtitle: Text(state.currentDateTime.toString().split('.')[0]),
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
          ListTile(
            title: const Text('天气'),
            subtitle: state.currentWeather.isNotEmpty
                ? Text('${state.currentWeather[2]} ${state.currentWeather[1]}°C')
                : null,
            trailing: state.isProcessing
                ? const CircularProgressIndicator()
                : IconButton.filledTonal(
                    onPressed: () {
                      logic.getWeather();
                    },
                    icon: const Icon(Icons.location_on),
                  ),
          ),
          ListTile(
            title: const Text('分类'),
            subtitle: state.categoryName.isNotEmpty ? Text(state.categoryName) : null,
            trailing: IconButton.filledTonal(
              onPressed: () {
                showModalBottomSheet(
                    showDragHandle: true,
                    useSafeArea: true,
                    context: context,
                    builder: (context) {
                      return const CategoryAddComponent();
                    });
              },
              icon: const Icon(Icons.category),
            ),
          ),
          ListTile(
            title: const Text('标签'),
            subtitle: buildTagList(),
            trailing: IconButton.filledTonal(
              icon: const Icon(Icons.tag),
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        content: TextField(
                          maxLines: 1,
                          controller: logic.tagTextEditingController,
                          decoration: InputDecoration(
                            fillColor: colorScheme.secondaryContainer,
                            border: const UnderlineInputBorder(
                              borderRadius: AppBorderRadius.smallBorderRadius,
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            labelText: '标签',
                          ),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () {
                                logic.cancelAddTag();
                              },
                              child: Text(i18n.cancel)),
                          TextButton(
                              onPressed: () {
                                logic.addTag();
                              },
                              child: Text(i18n.ok))
                        ],
                      );
                    });
              },
            ),
          ),
          ListTile(
            title: const Text('心情指数'),
            subtitle: Obx(() {
              return Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    MoodIconComponent(value: state.currentMoodRate.value),
                    Expanded(
                      child: Slider(
                          value: state.currentMoodRate.value,
                          divisions: 10,
                          label: '${(state.currentMoodRate.value * 100).toStringAsFixed(0)}%',
                          activeColor: Color.lerp(
                              AppColor.emoColorList.first, AppColor.emoColorList.last, state.currentMoodRate.value),
                          onChanged: (value) {
                            logic.changeRate(value);
                          }),
                    ),
                  ],
                ),
              );
            }),
          ),
          ListTile(
            title: const Text('图片'),
            subtitle: buildImage(),
          ),
          ListTile(
            title: const Text('音频'),
            subtitle: buildAudioPlayer(),
          ),
        ],
      );
    }

    Widget buildWriting() {
      return Column(
        children: [
          TextField(
            maxLines: 1,
            controller: logic.titleTextEditingController,
            focusNode: logic.titleFocusNode,
            decoration: const InputDecoration(
                border: UnderlineInputBorder(), contentPadding: EdgeInsets.all(12.0), hintText: '标题'),
          ),
          Expanded(
            child: QuillEditor.basic(
              focusNode: logic.contentFocusNode,
              controller: logic.quillController,
              configurations: const QuillEditorConfigurations(
                padding: EdgeInsets.all(12.0),
                placeholder: '正文',
                sharedConfigurations: QuillSharedConfigurations(),
                expands: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Obx(() {
                  return Text('字数：${state.totalCount.value.toString()}');
                })
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: QuillSimpleToolbar(
              controller: logic.quillController,
              configurations: const QuillSimpleToolbarConfigurations(
                showFontFamily: false,
                showFontSize: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showAlignmentButtons: true,
                showClipboardPaste: false,
                showClipboardCut: false,
                showClipboardCopy: false,
                headerStyleType: HeaderStyleType.buttons,
                sharedConfigurations: QuillSharedConfigurations(),
              ),
            ),
          ),
        ],
      );
    }

    return GetBuilder<EditLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return Scaffold(
          appBar: AppBar(
            title: state.isNew == true ? const Text('新增日记') : const Text('编辑日记'),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () {
                  logic.unFocus();
                  state.isNew ? logic.saveDiary() : logic.updateDiary();
                },
                tooltip: '保存',
              ),
            ],
          ),
          body: PageView(
            controller: logic.pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [KeepAliveWrapper(child: buildWriting()), KeepAliveWrapper(child: buildDetail())],
          ),
          bottomNavigationBar: Obx(() {
            return NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.edit_outlined),
                  label: '撰写',
                  selectedIcon: Icon(Icons.edit),
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_outlined),
                  label: '更多',
                  selectedIcon: Icon(Icons.more),
                )
              ],
              selectedIndex: state.tabIndex.value,
              onDestinationSelected: (index) {
                logic.selectTabView(index);
              },
            );
          }),
        );
      },
    );
  }
}
