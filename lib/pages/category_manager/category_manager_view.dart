import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:mood_diary/components/loading/loading.dart';
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
        title: const Text('分类管理'),
      ),
      body: Obx(() {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: !state.isFetching.value
              ? ListView.builder(
                  itemBuilder: (context, index) {
                    return ListTile(
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
                              var res = await showTextInputDialog(
                                  context: context,
                                  title: '编辑分类',
                                  textFields: [
                                    DialogTextField(
                                      hintText: '分类名称',
                                      initialText: state
                                          .categoryList[index].categoryName,
                                    )
                                  ]);
                              if (res != null) {
                                logic.editCategory(state.categoryList[index].id,
                                    text: res.first);
                              }
                            },
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            onPressed: () {
                              logic
                                  .deleteCategory(state.categoryList[index].id);
                            },
                            icon: const Icon(Icons.delete_forever),
                            color: colorScheme.error,
                          )
                        ],
                      ),
                    );
                  },
                  itemCount: state.categoryList.length,
                )
              : const Center(
                  child: Processing(),
                ),
        );
      }),
      floatingActionButton: Obx(() {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: !state.isFetching.value
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    var res = await showTextInputDialog(
                        context: context,
                        title: '添加分类',
                        textFields: [
                          const DialogTextField(
                            hintText: '分类名称',
                          )
                        ]);
                    if (res != null) {
                      logic.addCategory(text: res.first);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加分类'),
                )
              : const SizedBox.shrink(),
        );
      }),
    );
  }
}
