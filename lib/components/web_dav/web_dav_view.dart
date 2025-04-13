import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/webdav.dart';
import 'package:moodiary/components/tile/setting_tile.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'web_dav_logic.dart';
import 'web_dav_state.dart';

class WebDavComponent extends StatelessWidget {
  const WebDavComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final WebDavLogic logic = Get.put(WebDavLogic());
    final WebDavState state = Bind.find<WebDavLogic>().state;

    return ExpansionTile(
      leading: const Icon(Icons.backup_rounded),
      title: Text(context.l10n.backupSyncWebdav),
      subtitle: Obx(() {
        return state.hasOption.value
            ? Row(
              children: [
                Text(
                  '${context.l10n.backupSyncWebdavOption} ${context.l10n.backupSyncWebDAVConnectivity} ',
                ),
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
            : Text(context.l10n.backupSyncWebdavNoOption);
      }),
      children: [
        Obx(() {
          return AdaptiveSwitchListTile(
            value: state.autoSync.value,
            onChanged: logic.setAutoSync,
            title: Text(context.l10n.webdavSyncWhenStartUp),
            subtitle: context.l10n.webdavSyncWhenStartUpDes,
          );
        }),
        Obx(() {
          return AdaptiveSwitchListTile(
            value: state.autoSyncAfterChange.value,
            onChanged: logic.setAutoSyncAfterChange,
            title: Text(context.l10n.webdavSyncAfterChange),
            subtitle: context.l10n.webdavSyncAfterChangeDes,
          );
        }),
        Obx(() {
          return AdaptiveSwitchListTile(
            value: state.syncEncryption.value,
            onChanged: state.hasUserKey.value ? logic.setSyncEncryption : null,
            title: Text(context.l10n.webdavSyncEncryption),
            subtitle: context.l10n.webdavSyncEncryptionDes,
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
                    labelText: context.l10n.webdavOptionServer,
                    border: const OutlineInputBorder(
                      borderRadius: AppBorderRadius.smallBorderRadius,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: FaIcon(FontAwesomeIcons.globe, size: 16),
                    ),
                    fillColor: context.theme.colorScheme.surfaceContainer,
                    filled: true,
                  ),
                  focusNode: logic.webDavUrlFocusNode,
                  controller: logic.webDavUrlController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.webdavOptionServerDes;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    logic.webDavUrlController.text = value ?? '';
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: context.l10n.webdavOptionUsername,
                    border: const OutlineInputBorder(
                      borderRadius: AppBorderRadius.smallBorderRadius,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: FaIcon(FontAwesomeIcons.solidUser, size: 16),
                    ),
                    fillColor: context.theme.colorScheme.surfaceContainer,
                    filled: true,
                  ),
                  textInputAction: TextInputAction.next,
                  focusNode: logic.usernameFocusNode,
                  controller: logic.usernameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.webdavOptionUsernameDes;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    logic.usernameController.text = value ?? '';
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: context.l10n.webdavOptionPassword,
                    border: const OutlineInputBorder(
                      borderRadius: AppBorderRadius.smallBorderRadius,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: FaIcon(FontAwesomeIcons.lock, size: 16),
                    ),
                    fillColor: context.theme.colorScheme.surfaceContainer,
                    filled: true,
                  ),
                  textInputAction: TextInputAction.done,
                  focusNode: logic.passwordFocusNode,
                  controller: logic.passwordController,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.webdavOptionPasswordDes;
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
                        context.l10n.webdavOptionDelete,
                        style: TextStyle(
                          color: context.theme.colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: logic.submitForm,
                      child: Obx(() {
                        return Text(
                          !state.hasOption.value
                              ? context.l10n.webdavOptionSave
                              : context.l10n.webdavOptionUpdate,
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
