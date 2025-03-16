import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/loading.dart';
import 'package:moodiary/components/tile/setting_tile.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

import 'category_manager_logic.dart';

class CategoryManagerPage extends StatelessWidget {
  const CategoryManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<CategoryManagerLogic>();
    final state = Bind.find<CategoryManagerLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingFunctionCategoryManage),
        leading: const PageBackButton(),
      ),
      body: Obx(() {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: !state.isFetching.value
              ? ListView.builder(
                  itemBuilder: (context, index) {
                    return AdaptiveListTile(
                      title: Text(state.categoryList[index].categoryName),
                      subtitle: Text(
                        state.categoryList[index].id,
                        style: const TextStyle(fontSize: 8),
                      ),
                      onTap: null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              final res = await showTextInputDialog(
                                  context: context,
                                  title: l10n.categoryManageEdit,
                                  textFields: [
                                    DialogTextField(
                                      hintText: l10n.categoryManageName,
                                      initialText: state
                                          .categoryList[index].categoryName,
                                    )
                                  ]);
                              if (res != null) {
                                logic.editCategory(state.categoryList[index].id,
                                    text: res.first);
                              }
                            },
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            onPressed: () {
                              logic
                                  .deleteCategory(state.categoryList[index].id);
                            },
                            icon: const Icon(Icons.delete_forever_rounded),
                            color: colorScheme.error,
                          )
                        ],
                      ),
                    );
                  },
                  itemCount: state.categoryList.length,
                )
              : const MoodiaryLoading(),
        );
      }),
      floatingActionButton: Obx(() {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: !state.isFetching.value
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final res = await showTextInputDialog(
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
                  icon: const Icon(Icons.add),
                  label: Text(l10n.categoryManageAdd),
                )
              : const SizedBox.shrink(),
        );
      }),
    );
  }
}
