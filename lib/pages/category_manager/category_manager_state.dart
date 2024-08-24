import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';

class CategoryManagerState {
  late RxList<Category> categoryList;

  CategoryManagerState() {
    categoryList = <Category>[].obs;

    ///Initialize variables
  }
}
