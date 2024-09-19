import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:markdown_widget/markdown_widget.dart';

import 'assistant_logic.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<AssistantLogic>();
    final state = Bind.find<AssistantLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;

    final modelMap = {
      0: 'hunyuan-lite',
      1: 'hunyuan-standard',
      2: 'hunyuan-pro',
      3: 'hunyuan-turbo',
    };

    Widget buildInput() {
      return Container(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
                onPressed: () {
                  logic.homeLogic.state.navigatorBarHeight == .0 ? logic.openBar() : logic.closeBar();
                },
                icon: AnimatedBuilder(
                    animation: logic.barAnimation,
                    child: const Icon(Icons.keyboard_arrow_up_outlined),
                    builder: (context, widget) {
                      return Transform.rotate(
                        angle: pi * logic.barAnimation.value,
                        child: widget,
                      );
                    })),
            Expanded(
                child: TextField(
              focusNode: logic.focusNode,
              controller: logic.textEditingController,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                  fillColor: colorScheme.surfaceContainerHighest,
                  filled: true,
                  isDense: true,
                  hintText: '消息',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24.0)),
                    borderSide: BorderSide.none,
                  )),
            )),
            IconButton.filled(
                onPressed: () {
                  logic.checkGetAi();
                },
                icon: const Icon(Icons.arrow_upward))
          ],
        ),
      );
    }

    Widget buildChat() {
      return SliverPadding(
        padding: const EdgeInsets.all(4.0),
        sliver: SliverList.builder(
          itemBuilder: (context, index) {
            var timeList = state.messages.keys.toList();
            var messageList = state.messages.values.toList();
            if (messageList[index].role == 'user') {
              return Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: 8.0,
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.circleQuestion,
                            size: 16.0,
                          ),
                          Text(
                            DateFormat.jms().format(timeList[index]),
                          )
                        ],
                      ),
                      MarkdownBlock(
                        data: messageList[index].content,
                        selectable: true,
                        config: colorScheme.brightness == Brightness.dark
                            ? MarkdownConfig.darkConfig
                            : MarkdownConfig.defaultConfig,
                      )
                    ],
                  ),
                ),
              );
            } else {
              return Card.filled(
                color: colorScheme.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: 8.0,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.bots,
                            color: colorScheme.tertiary,
                          ),
                          Text(
                            DateFormat.jms().format(timeList[index]),
                          )
                        ],
                      ),
                      MarkdownBlock(
                        data: messageList[index].content,
                        selectable: true,
                        config: colorScheme.brightness == Brightness.dark
                            ? MarkdownConfig.darkConfig
                            : MarkdownConfig.defaultConfig,
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          itemCount: state.messages.length,
        ),
      );
    }

    Widget buildEmpty() {
      return const Center(
        child: FaIcon(
          FontAwesomeIcons.comments,
          size: 46.0,
        ),
      );
    }

    return GetBuilder<AssistantLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    controller: logic.scrollController,
                    slivers: [
                      SliverAppBar(
                        title: Text(i18n.homeNavigatorAssistant),
                        pinned: true,
                        actions: [
                          Obx(() {
                            return Text(modelMap[state.modelVersion.value]!);
                          }),
                          IconButton(
                              onPressed: () {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return SimpleDialog(
                                        title: const Text('选择模型'),
                                        children: List.generate(modelMap.length, (index) {
                                          return Obx(() {
                                            return SimpleDialogOption(
                                              child: Row(
                                                spacing: 4.0,
                                                children: [
                                                  Text(modelMap[index]!),
                                                  if (state.modelVersion.value == index) ...[const Icon(Icons.check)]
                                                ],
                                              ),
                                              onPressed: () {
                                                logic.changeModel(index);
                                              },
                                            );
                                          });
                                        }),
                                      );
                                    });
                              },
                              icon: const Icon(Icons.change_circle_outlined)),
                          IconButton(
                              onPressed: () {
                                logic.newChat();
                              },
                              icon: const Icon(Icons.refresh)),
                        ],
                      ),
                      buildChat(),
                    ],
                  ),
                ),
                buildInput()
              ],
            ),
            if (state.messages.isEmpty) ...[buildEmpty()]
          ],
        );
      },
    );
  }
}
