import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'recycle_logic.dart';

class RecyclePage extends StatelessWidget {
  const RecyclePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<RecycleLogic>();
    final state = Bind.find<RecycleLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return GetBuilder<RecycleLogic>(
      
      
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              '回收站',
            ),
          ),
          body: ListView.builder(
            itemBuilder: (context, index) {
              return ListTile(
                onTap: null,
                title: Text(state.diaryList[index].time.toString().split('.')[0]),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      children: [
                        IconButton(
                          onPressed: () {
                            logic.showDiary(state.diaryList[index]);
                          },
                          icon: const Icon(Icons.settings_backup_restore),
                          style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                        const Text('恢复'),
                      ],
                    ),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () {
                            logic.deleteDiary(index);
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
            itemCount: state.diaryList.length,
          ),
        );
      },
    );
  }
}
