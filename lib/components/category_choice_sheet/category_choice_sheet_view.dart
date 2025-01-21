import 'package:flutter/material.dart';
import 'package:moodiary/components/loading/loading.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

import 'category_choice_sheet_logic.dart';
import 'category_choice_sheet_state.dart';

class CategoryChoiceSheetComponent extends StatelessWidget {
  const CategoryChoiceSheetComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final CategoryChoiceSheetLogic logic = Get.put(CategoryChoiceSheetLogic());
    final CategoryChoiceSheetState state =
        Bind.find<CategoryChoiceSheetLogic>().state;

    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;

    return GetBuilder<CategoryChoiceSheetLogic>(
      assignId: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Obx(() {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !state.isFetching.value
                    ? Wrap(
                        spacing: 4.0,
                        runSpacing: 4.0,
                        alignment: WrapAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.categoryAllCategory,
                                style: textStyle.titleMedium,
                              ),
                              Text(
                                state.categoryList.length.toString(),
                                style: textStyle.titleMedium,
                              )
                            ],
                          ),
                          ActionChip(
                            label: Text(l10n.categoryAll),
                            onPressed: () {
                              logic.selectCategory(categoryId: null);
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            backgroundColor: colorScheme.tertiaryContainer,
                          ),
                          ...List.generate(state.categoryList.value.length,
                              (index) {
                            return ActionChip(
                              label: Text(
                                  state.categoryList.value[index].categoryName),
                              onPressed: () {
                                logic.selectCategory(
                                    categoryId:
                                        state.categoryList.value[index].id);
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              backgroundColor: colorScheme.secondaryContainer,
                            );
                          }),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                logic.toCategoryManage(context);
                              },
                              child: Text(l10n.settingFunctionCategoryManage),
                            ),
                          )
                        ],
                      )
                    : const Center(
                        child: Processing(),
                      ),
              );
            }),
          ),
        );
      },
    );
  }
}
