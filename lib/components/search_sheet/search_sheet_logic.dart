import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/components/keyboard_listener/keyboard_listener.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:throttling/throttling.dart';

import 'search_sheet_state.dart';

class SearchSheetLogic extends GetxController {
  final SearchSheetState state = SearchSheetState();
  late TextEditingController textEditingController = TextEditingController();
  late FocusNode focusNode = FocusNode();

  late final KeyboardObserver _keyboardObserver;

  late final Throttling _throttling = Throttling(
    duration: const Duration(milliseconds: 500),
  );

  String _lastText = '';

  Timer? _timer;

  @override
  void onInit() {
    _keyboardObserver = KeyboardObserver(
      onHeightChanged: (height) {
        if (height > 0) {
          state.keyboardHeight.value = height;
        }
      },
      onStateChanged: (state) {
        switch (state) {
          case KeyboardState.opening:
            break;
          case KeyboardState.closing:
            unFocus();
            break;
          case KeyboardState.closed:
            break;
          case KeyboardState.unknown:
            break;
        }
      },
    );
    _keyboardObserver.start();
    textEditingController.addListener(() {
      _throttling.throttle(() async {
        await doSearch();
      });
    });

    // 兜底轮询：捕捉被节流（仅前沿触发）丢弃的尾部输入。
    // doSearch 内部会对比 _lastText 自行去重，文本未变时是空操作。
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      await doSearch();
    });
    super.onInit();
  }

  @override
  void onClose() {
    _keyboardObserver.stop();
    textEditingController.dispose();
    focusNode.dispose();
    _throttling.close();
    _timer?.cancel();
    _timer = null;
    super.onClose();
  }

  void unFocus() {
    focusNode.unfocus();
  }

  void clear() {
    state.searchList.clear();
    state.totalCount.value = 0;
    state.queryList = [];
    state.isSearching.value = false;
    update();
  }

  Future<void> doSearch() async {
    final currentText = textEditingController.text.trim();
    if (currentText == _lastText) {
      return;
    }
    if (currentText.isBlank) {
      _lastText = currentText;
      clear();
      return;
    }
    state.isSearching.value = true;
    _lastText = currentText;
    try {
      // 纯 Dart 分词：按空白切分为多个关键词，中文整串作为一个关键词直接子串匹配
      final queryList =
          currentText.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      state.searchList = await IsarUtil.searchDiaries(queryList: queryList);
      state.totalCount.value = state.searchList.length;
      state.queryList = queryList;
    } finally {
      state.isSearching.value = false;
    }
  }
}
