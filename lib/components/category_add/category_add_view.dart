import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

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
                        label: Text(l10n.categoryManageAdd),
                        onPressed: () async {
                          var res = await showTextInputDialog(
                              context: context,
                              title: l10n.categoryManageAdd,
                              textFields: [
                                DialogTextField(
                                  hintText: l10n.categoryManageName,
                                )
                              ]);
                          if (res != null) {
                            logic.addCategory(text: res.first);
                          }
                        },
                      ),
                      Text(state.categoryList.length.toString())
                    ],
                  ),
                  ActionChip(
                    label: Text(l10n.categoryNoCategory),
                    onPressed: () {
                      logic.cancelCategory(context);
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    backgroundColor: colorScheme.tertiaryContainer,
                  ),
                  ...List.generate(state.categoryList.value.length, (index) {
                    return ActionChip(
                      label: Text(state.categoryList.value[index].categoryName),
                      onPressed: () {
                        logic.selectCategory(index, context);
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
