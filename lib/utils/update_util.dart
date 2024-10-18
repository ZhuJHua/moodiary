import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/api/api.dart';
import 'package:mood_diary/common/models/shiply.dart';
import 'package:mood_diary/components/update_dialog/update_dialog_view.dart';
import 'package:mood_diary/utils/utils.dart';

import 'channel.dart';

class UpdateUtil {
  Future<void> initShiply() async {
    //如果不是首次启动，就初始化
    if (Utils().prefUtil.getValue<bool>('firstStart') == false) {
      //初始化shiply
      await ShiplyChannel.initShiply();
    }
  }

  Future<ShiplyResponse?> checkUpdate() async {
    var res = await ShiplyChannel.checkUpdate();
    if (res != null) {
      return ShiplyResponse.fromJson(jsonDecode(res));
    } else {
      return null;
    }
  }

  //通过github检查更新
  Future<void> checkShouldUpdate(String currentVersion, {bool handle = false}) async {
    var githubRelease = await Api().getGithubRelease();
    if (githubRelease != null) {
      //当需要更新版本时
      if (githubRelease.tagName!.split('v')[1].compareTo(currentVersion) > 0) {
        Get.dialog(UpdateDialogComponent(githubRelease: githubRelease));
      } else if (handle) {
        Utils().noticeUtil.showToast('已经是最新版本');
      }
    }
  }

  TextSpan buildReleaseNote(String version, List<String> fix, List<String> add) {
    // 创建一个文本段落列表，用于存放每个部分的文本段
    List<TextSpan> children = [];
    final textStyle = Theme.of(Get.context!).textTheme;
    // 添加版本信息
    children.add(TextSpan(
      text: '$version\n',
      style: textStyle.titleSmall!.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ));

    // 添加新增内容
    if (add.isNotEmpty) {
      children.add(TextSpan(
        text: '新增:\n',
        style: textStyle.titleSmall,
      ));
      // 遍历新增内容列表，将每个新增项目添加到文本段落中
      for (String item in add) {
        children.add(TextSpan(
          text: '• $item\n',
          style: textStyle.bodySmall,
        ));
      }
    }

    // 添加修复内容
    if (fix.isNotEmpty) {
      children.add(TextSpan(
        text: '修复:\n',
        style: textStyle.titleSmall,
      ));
      // 遍历修复内容列表，将每个修复项目添加到文本段落中
      for (String item in fix) {
        children.add(TextSpan(
          text: '• $item\n',
          style: textStyle.bodySmall,
        ));
      }
    }
    children.add(const TextSpan(text: '\n'));
    // 返回包含所有文本段的 TextSpan 对象
    return TextSpan(children: children);
  }
}
