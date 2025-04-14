import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/tile/setting_tile.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'recycle_logic.dart';

class RecyclePage extends StatelessWidget {
  const RecyclePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<RecycleLogic>();
    final state = Bind.find<RecycleLogic>().state;

    return GetBuilder<RecycleLogic>(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.settingRecycle),
            leading: const PageBackButton(),
          ),
          body: ListView.builder(
            itemBuilder: (context, index) {
              return AdaptiveListTile(
                onTap: null,
                title: Text(
                  state.diaryList[index].time.toString().split('.')[0],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        logic.showDiary(state.diaryList[index]);
                      },
                      icon: const Icon(Icons.settings_backup_restore_rounded),
                    ),
                    IconButton(
                      onPressed: () {
                        logic.deleteDiary(index);
                      },
                      icon: const Icon(Icons.delete_forever_rounded),
                      color: context.theme.colorScheme.error,
                    ),
                  ],
                ),
              );
            },
            itemCount: state.diaryList.length,
          ),
        );
      },
    );
  }
}
