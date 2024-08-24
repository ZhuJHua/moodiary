import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class AgreementPage extends StatelessWidget {
  const AgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    // final logic = Bind.find<AgreementLogic>();
    // final state = Bind.find<AgreementLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('用户协议')),
      body: MarkdownWidget(
        data: '''# 用户协议

*江有汜*（以下简称“我们”）依据本协议为用户（以下简称“你”）提供*心绪日记*服务。本协议对你和我们均具有法律约束力。

#### 一、本服务的功能

你可以使用本服务撰写日记。

#### 二、责任范围及限制

你使用本服务得到的结果仅供参考，实际情况以官方为准。

#### 三、隐私保护

我们重视对你隐私的保护，你的个人隐私信息将根据《隐私政策》受到保护与规范，详情请参阅《隐私政策》。

#### 四、其他条款

4.1 本协议所有条款的标题仅为阅读方便，本身并无实际涵义，不能作为本协议涵义解释的依据。

4.2 本协议条款无论因何种原因部分无效或不可执行，其余条款仍有效，对双方具有约束力。''',
        selectable: true,
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        config: colorScheme.brightness == Brightness.dark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig,
      ),
    );
  }
}
