import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'set_password_logic.dart';

class SetPasswordComponent extends StatelessWidget {
  const SetPasswordComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SetPasswordLogic());
    final state = Bind.find<SetPasswordLogic>().state;

    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;

    final buttonSize = (textStyle.displayLarge!.fontSize! * textStyle.displayLarge!.height!);
    Widget buildNumButton(String num) {
      return Ink(
        decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
        child: InkWell(
          borderRadius: BorderRadius.all(Radius.circular(buttonSize / 2)),
          onTap: () async {
            await logic.updatePassword(num);
          },
          child: Center(
              child: Text(
            num,
            style: textStyle.displaySmall,
          )),
        ),
      );
    }

    Widget buildDeleteButton() {
      return Ink(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: InkWell(
          borderRadius: BorderRadius.all(Radius.circular(buttonSize / 2)),
          onTap: () {
            logic.deletePassword();
          },
          child: const Icon(
            Icons.backspace,
          ),
        ),
      );
    }

    List<Widget> buildPasswordIndicator() {
      return List.generate(4, (index) {
        return Obx(() {
          return Icon(
            Icons.circle,
            size: 16,
            color: Color.lerp(
                state.password.value.length > index ? colorScheme.onSurface : colorScheme.surfaceContainerHighest,
                Colors.red,
                logic.animation.value),
          );
        });
      });
    }

    return GetBuilder<SetPasswordLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              return Text(
                state.checkPassword.value.isEmpty ? '请输入密码' : '请确认密码',
                style: textStyle.titleMedium,
              );
            }),
            const SizedBox(
              height: 16.0,
            ),
            AnimatedBuilder(
              animation: logic.animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(logic.interpolate(logic.animation.value), 0),
                  child: Wrap(
                    spacing: 16.0,
                    children: buildPasswordIndicator(),
                  ),
                );
              },
            ),
            const SizedBox(
              height: 32.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: buttonSize * 3 + 20,
                  height: buttonSize * 4 + 30,
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: [
                      buildNumButton('1'),
                      buildNumButton('2'),
                      buildNumButton('3'),
                      buildNumButton('4'),
                      buildNumButton('5'),
                      buildNumButton('6'),
                      buildNumButton('7'),
                      buildNumButton('8'),
                      buildNumButton('9'),
                      const SizedBox(),
                      buildNumButton('0'),
                      buildDeleteButton()
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16.0,
            ),
          ],
        );
      },
    );
  }
}
