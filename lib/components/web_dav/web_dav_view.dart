import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/webdav.dart';

import 'web_dav_logic.dart';
import 'web_dav_state.dart';

class WebDavComponent extends StatelessWidget {
  const WebDavComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final WebDavLogic logic = Get.put(WebDavLogic());
    final WebDavState state = Bind.find<WebDavLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      leading: const Icon(Icons.backup_rounded),
      title: const Text('WebDav-测试版'),
      subtitle: Obx(() {
        return state.hasOption.value
            ? Row(
                children: [
                  const Text('已配置 连通性 '),
                  Icon(
                    Icons.circle,
                    color: switch (state.connectivityStatus.value) {
                      WebDavConnectivityStatus.connected =>
                        WebDavOptions.connectivityColor,
                      WebDavConnectivityStatus.unconnected =>
                        WebDavOptions.unConnectivityColor,
                      WebDavConnectivityStatus.connecting =>
                        WebDavOptions.connectingColor,
                    },
                    size: 16,
                  ),
                ],
              )
            : const Text('未配置');
      }),
      children: [
        Obx(() {
          return SwitchListTile(
            value: state.autoSync.value,
            onChanged: logic.setAutoSync,
            title: const Text('启动时同步'),
            subtitle: const Text('打开应用时自动同步日记'),
          );
        }),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: state.formKey,
            child: Column(
              spacing: 16.0,
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText: '服务器地址',
                    border: const OutlineInputBorder(
                        borderRadius: AppBorderRadius.smallBorderRadius),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: FaIcon(
                        FontAwesomeIcons.globe,
                        size: 16,
                      ),
                    ),
                    fillColor: colorScheme.surfaceContainer,
                    filled: true,
                  ),
                  focusNode: logic.webDavUrlFocusNode,
                  controller: logic.webDavUrlController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入服务器地址';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    logic.webDavUrlController.text = value ?? '';
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: '用户名',
                    border: const OutlineInputBorder(
                        borderRadius: AppBorderRadius.smallBorderRadius),
                    prefixIcon: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: FaIcon(
                          FontAwesomeIcons.solidUser,
                          size: 16,
                        )),
                    fillColor: colorScheme.surfaceContainer,
                    filled: true,
                  ),
                  textInputAction: TextInputAction.next,
                  focusNode: logic.usernameFocusNode,
                  controller: logic.usernameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入用户名';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    logic.usernameController.text = value ?? '';
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: '密码',
                    border: const OutlineInputBorder(
                        borderRadius: AppBorderRadius.smallBorderRadius),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: FaIcon(
                        FontAwesomeIcons.lock,
                        size: 16,
                      ),
                    ),
                    fillColor: colorScheme.surfaceContainer,
                    filled: true,
                  ),
                  textInputAction: TextInputAction.done,
                  focusNode: logic.passwordFocusNode,
                  controller: logic.passwordController,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    logic.passwordController.text = value ?? '';
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: logic.removeWebDavOption,
                        child: Text(
                          '删除配置',
                          style: TextStyle(color: colorScheme.error),
                        )),
                    TextButton(
                      onPressed: logic.submitForm,
                      child: Obx(() {
                        return Text(!state.hasOption.value ? '保存配置' : '更新配置');
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
