import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';

import 'category_manager_logic.dart';

class CategoryManagerPage extends StatelessWidget {
  const CategoryManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<CategoryManagerLogic>();
    final state = Bind.find<CategoryManagerLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;

    Widget inputDialog(Function() operate) {
      return AlertDialog(
        title: TextField(
          maxLines: 1,
          controller: logic.textEditingController,
          decoration: InputDecoration(
            fillColor: colorScheme.secondaryContainer,
            border: const UnderlineInputBorder(
              borderRadius: AppBorderRadius.smallBorderRadius,
              borderSide: BorderSide.none,
            ),
            filled: true,
            labelText: '分类',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Get.backLegacy();
              },
              child: Text(i18n.cancel)),
          TextButton(onPressed: operate, child: Text(i18n.ok))
        ],
      );
    }

    return GetBuilder<CategoryManagerLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('分类管理'),
          ),
          body: Obx(() {
            return ListView.builder(
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(state.categoryList.value[index].categoryName),
                  onTap: null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          IconButton(
                            onPressed: () {
                              logic.editInput(state.categoryList.value[index].categoryName);
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return inputDialog(() {
                                      logic.editCategory(state.categoryList.value[index].id);
                                    });
                                  });
                            },
                            icon: const Icon(Icons.edit),
                            style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          ),
                          const Text('编辑'),
                        ],
                      ),
                      Column(
                        children: [
                          IconButton(
                            onPressed: () {
                              logic.deleteCategory(state.categoryList.value[index].id);
                            },
                            icon: const Icon(Icons.delete_forever),
                            style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            color: colorScheme.error,
                          ),
                          Text(
                            '删除',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
              itemCount: state.categoryList.value.length,
            );
          }),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              logic.clearInput();
              showDialog(
                  context: context,
                  builder: (context) {
                    return inputDialog(() {
                      logic.addCategory();
                    });
                  });
            },
            icon: const Icon(Icons.add),
            label: const Text('添加分类'),
          ),
        );
      },
    );
  }
}
