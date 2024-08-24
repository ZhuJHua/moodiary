import 'package:isar/isar.dart';

part 'category.g.dart';

@collection
class Category {
  @Id()
  late String id;

  //分类名称
  late String categoryName;
}
