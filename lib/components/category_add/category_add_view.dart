import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';

import '../../main.dart';
import 'category_add_logic.dart';

class CategoryAddComponent extends StatelessWidget {
  const CategoryAddComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(CategoryAddLogic());
    final state = Bind.find<CategoryAddLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return GetBuilder<CategoryAddLogic>(
      assignId: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Obx(() {
              return Wrap(
                spacing: 4.0,
                runSpacing: 4.0,
                alignment: WrapAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('添加'),
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  content: TextField(
                                    maxLines: 1,
                                    controller: logic.textEditingController,
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
                                          logic.cancelAdd();
                                        },
                                        child: Text(l10n.cancel)),
                                    TextButton(
                                        onPressed: () async {
                                          await logic.addCategory();
                                        },
                                        child: Text(l10n.ok))
                                  ],
                                );
                              });
                        },
                      ),
                      Text(state.categoryList.length.toString())
                    ],
                  ),
                  ActionChip(
                    label: const Text('无分类'),
                    onPressed: () {
                      logic.cancelCategory();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    backgroundColor: colorScheme.tertiaryContainer,
                  ),
                  ...List.generate(state.categoryList.value.length, (index) {
                    return ActionChip(
                      label: Text(state.categoryList.value[index].categoryName),
                      onPressed: () {
                        logic.selectCategory(index);
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      backgroundColor: colorScheme.secondaryContainer,
                    );
                  }),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}
