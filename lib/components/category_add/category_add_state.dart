import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/category.dart';

class CategoryAddState {
  late RxList<Category> categoryList;

  CategoryAddState() {
    categoryList = <Category>[].obs;

    ///Initialize variables
  }
}
