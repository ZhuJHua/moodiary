import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/auth_util.dart';

import 'lock_logic.dart';

class LockPage extends StatelessWidget {
  const LockPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<LockLogic>();
    final state = Bind.find<LockLogic>().state;
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

    Widget buildBiometricsButton() {
      return Ink(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: InkWell(
          borderRadius: BorderRadius.all(Radius.circular(buttonSize / 2)),
          onTap: () async {
            if (await AuthUtil.check()) {
              logic.checked();
            }
          },
          child: const Icon(
            Icons.fingerprint,
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

    return GetBuilder<LockLogic>(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
          ),
          body: Center(
            child: Column(
              spacing: 16.0,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock),
                Text(
                  '请输入密码',
                  style: textStyle.titleMedium,
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
                SizedBox(
                  width: buttonSize * 3 + 20,
                  height: buttonSize * 4 + 30,
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    physics: const NeverScrollableScrollPhysics(),
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
                      buildBiometricsButton(),
                      buildNumButton('0'),
                      buildDeleteButton()
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
