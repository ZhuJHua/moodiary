import 'package:get/get.dart';

import '../../common/models/isar/category.dart';

class CategoryChoiceSheetState {
  RxList<Category> categoryList = <Category>[].obs;

  RxBool isFetching = true.obs;

  CategoryChoiceSheetState();
}
