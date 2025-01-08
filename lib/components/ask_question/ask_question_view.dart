import 'package:flutter/material.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:refreshed/refreshed.dart';

import 'ask_question_logic.dart';

class AskQuestionComponent extends StatelessWidget {
  const AskQuestionComponent({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(AskQuestionLogic());
    final state = Bind.find<AskQuestionLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    Widget buildInput() {
      return Container(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
                child: TextField(
              focusNode: logic.focusNode,
              controller: logic.textEditingController,
              maxLines: 1,
              decoration: InputDecoration(
                  fillColor: colorScheme.surfaceContainerHighest,
                  filled: true,
                  isDense: true,
                  hintText: '提问',
                  border: const OutlineInputBorder(
                    borderRadius: AppBorderRadius.largeBorderRadius,
                    borderSide: BorderSide.none,
                  )),
            )),
            IconButton.filled(
                onPressed: () async {
                  await logic.ask(content);
                },
                icon: const Icon(Icons.arrow_upward))
          ],
        ),
      );
    }

    Widget buildQuestion(String text, BoxConstraints constraint) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraint.maxWidth * 0.618),
            child: Card.filled(
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  text,
                  style: TextStyle(color: colorScheme.onSecondaryContainer),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget buildAnswer(String text, BoxConstraints constraint) {
      return Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraint.maxWidth * 0.618),
            child: Card.filled(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  text,
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget buildChat(BoxConstraints constraint) {
      return ListView.builder(
        controller: logic.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        itemBuilder: (context, index) {
          return index & 1 == 0
              ? buildQuestion(state.qaList[index], constraint)
              : buildAnswer(state.qaList[index], constraint);
        },
        itemCount: state.qaList.length,
      );
    }

    return LayoutBuilder(
      builder: (context, constraint) {
        return GetBuilder<AskQuestionLogic>(
          assignId: true,
          builder: (_) {
            return Column(
              children: [
                Expanded(child: Obx(() {
                  return buildChat(constraint);
                })),
                buildInput()
              ],
            );
          },
        );
      },
    );
  }
}
