import 'package:moodiary/common/models/isar/category.dart';
import 'package:refreshed/refreshed.dart';

class CategoryAddState {
  late RxList<Category> categoryList;

  CategoryAddState() {
    categoryList = <Category>[].obs;

    ///Initialize variables
  }
}
