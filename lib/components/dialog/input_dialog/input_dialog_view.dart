import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'input_dialog_logic.dart';

class InputDialogComponent extends StatelessWidget {
  const InputDialogComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final InputDialogLogic logic = Get.put(InputDialogLogic());
    return Container();
  }
}
