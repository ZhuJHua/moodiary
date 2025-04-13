import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/category.dart';

class CategoryManagerState {
  late RxList<Category> categoryList = <Category>[].obs;

  RxBool isFetching = true.obs;

  CategoryManagerState();
}
