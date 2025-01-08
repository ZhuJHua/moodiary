import 'package:mood_diary/common/models/isar/category.dart';
import 'package:refreshed/refreshed.dart';

class CategoryManagerState {
  late RxList<Category> categoryList = <Category>[].obs;

  RxBool isFetching = true.obs;

  CategoryManagerState();
}
