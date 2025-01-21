import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moodiary/main.dart';
import 'package:moodiary/utils/auth_util.dart';
import 'package:refreshed/refreshed.dart';

import 'lock_logic.dart';

class LockPage extends StatelessWidget {
  const LockPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<LockLogic>();
    final state = Bind.find<LockLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;

    final buttonSize =
        (textStyle.displayLarge!.fontSize! * textStyle.displayLarge!.height!);
    Widget buildNumButton(String num) {
      return Ink(
        decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
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
            Icons.keyboard_backspace_rounded,
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
            Icons.fingerprint_rounded,
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
                state.password.value.length > index
                    ? colorScheme.onSurface
                    : colorScheme.surfaceContainerHighest,
                Colors.red,
                logic.animation.value),
          );
        });
      });
    }

    return PopScope(
      canPop: state.lockType != 'pause',
      child: Scaffold(
        appBar: AppBar(
          leading: null,
          automaticallyImplyLeading: false,
        ),
        extendBodyBehindAppBar: true,
        body: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              spacing: 32.0,
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: state.isCheck.value
                        ? const FaIcon(
                            FontAwesomeIcons.unlock,
                            key: ValueKey('unlock'),
                          )
                        : const FaIcon(
                            FontAwesomeIcons.lock,
                            key: ValueKey('lock'),
                          ),
                  );
                }),
                Text(
                  l10n.lockEnterPassword,
                  style: textStyle.titleMedium,
                ),
                AnimatedBuilder(
                  animation: logic.animation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset:
                          Offset(logic.interpolate(logic.animation.value), 0),
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
                    padding: EdgeInsets.zero,
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
                      state.supportBiometrics
                          ? buildBiometricsButton()
                          : const Spacer(),
                      buildNumButton('0'),
                      buildDeleteButton()
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
