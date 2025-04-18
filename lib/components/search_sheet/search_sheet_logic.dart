import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/components/keyboard_listener/keyboard_listener.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/src/rust/api/jieba.dart';
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

    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final currentText = textEditingController.text.trim();
      if (currentText != _lastText) {
        _lastText = currentText;
        if (currentText.isNotBlank) {
          await doSearch();
        } else {
          clear();
        }
      }
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
      clear();
      return;
    }
    state.isSearching.value = true;
    _lastText = currentText;
    final queryList = await JiebaRs.cutForSearch(text: _lastText, hmm: true);
    state.searchList = await IsarUtil.searchDiaries(queryList: queryList);
    state.totalCount.value = state.searchList.length;
    state.queryList = queryList;
    state.isSearching.value = false;
  }
}
