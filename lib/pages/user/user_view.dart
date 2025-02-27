import 'package:flutter/material.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:refreshed/refreshed.dart';

import 'user_logic.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<UserLogic>();
    final state = Bind.find<UserLogic>().state;
    LogUtil.printInfo(state.session);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          FilledButton(
              onPressed: () {
                logic.signOut();
              },
              child: const Text('退出登录')),
        ],
      ),
    );
  }
}
