import 'package:flutter/material.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/isar.dart';
import 'search_sheet_state.dart';

class SearchSheetLogic extends GetxController {
  final SearchSheetState state = SearchSheetState();
  late TextEditingController textEditingController = TextEditingController();
  late FocusNode focusNode = FocusNode();

  @override
  void onClose() {
    textEditingController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  void clearSearch() {
    state.searchList = [];
    update();
  }

  Future<void> search() async {
    focusNode.unfocus();
    if (textEditingController.text != '') {
      state.isSearching.value = true;
      state.searchList =
          await IsarUtil.searchDiaries(textEditingController.text);
      state.totalCount.value = state.searchList.length;
      state.isSearching.value = false;
    }
  }
}
