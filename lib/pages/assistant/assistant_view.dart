import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:markdown_widget/markdown_widget.dart';

import 'assistant_logic.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<AssistantLogic>();
    final state = Bind.find<AssistantLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final modelName = ['hunyuan-lite', 'hunyuan-standard', 'hunyuan-pro'];
    return GetBuilder<AssistantLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return GestureDetector(
          onTap: () {
            logic.unFocus();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('AI 助手'),
              leading: IconButton(
                onPressed: () {
                  logic.handleBack();
                },
                icon: const Icon(Icons.arrow_back_outlined),
              ),
              actions: [
                IconButton(
                    onPressed: () {
                      logic.newChat();
                    },
                    icon: const Icon(Icons.refresh)),
              ],
            ),
            body: Column(
              children: [
                Flexible(
                    child: state.messages.isEmpty
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('暂无对话'),
                            ],
                          )
                        : ListView.builder(
                            controller: logic.scrollController,
                            itemBuilder: (context, index) {
                              if (state.messages[index].role == 'user') {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                  child: Text(
                                    state.messages[index].content,
                                    style: TextStyle(color: colorScheme.primary),
                                  ),
                                );
                              } else {
                                return Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(10.0),
                                    decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainer,
                                        borderRadius: const BorderRadius.all(Radius.circular(10.0))),
                                    child: MarkdownBlock(
                                      data: state.messages[index].content,
                                      selectable: true,
                                      config: colorScheme.brightness == Brightness.dark
                                          ? MarkdownConfig.darkConfig
                                          : MarkdownConfig.defaultConfig,
                                    ),
                                  ),
                                );
                              }
                            },
                            itemCount: state.messages.length,
                          )),
                Container(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('当前模型：${modelName[state.modelVersion]}'),
                          IconButton(
                              onPressed: () {
                                logic.changeModel();
                              },
                              icon: const Icon(Icons.change_circle_outlined))
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                              child: TextField(
                            focusNode: logic.focusNode,
                            controller: logic.textEditingController,
                            minLines: 1,
                            maxLines: 10,
                            decoration: InputDecoration(
                              fillColor: colorScheme.surfaceContainerHighest,
                              filled: true,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  logic.clearText();
                                },
                                icon: const Icon(Icons.cancel),
                              ),
                              hintText: '消息',
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.all(Radius.circular(20.0)),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.all(Radius.circular(20.0)),
                              ),
                            ),
                          )),
                          IconButton.filled(
                              onPressed: () {
                                logic.checkGetAi();
                              },
                              icon: const Icon(Icons.arrow_upward))
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
