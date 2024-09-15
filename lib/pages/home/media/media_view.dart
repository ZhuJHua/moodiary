import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';

import 'media_logic.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<MediaLogic>();
    final state = Bind.find<MediaLogic>().state;
    final i18n = AppLocalizations.of(context)!;
    return GetBuilder<MediaLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(i18n.homeNavigatorMedia),
            )
          ],
        );
      },
    );
  }
}
