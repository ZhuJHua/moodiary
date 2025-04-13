import 'package:isar/isar.dart';

part 'category.g.dart';

@collection
class Category {
  @Id()
  late String id;

  late String categoryName;

  String? parentId;

  @Index()
  String get level => parentId ?? 'root';

  Category();

  Map<String, dynamic> toJson() {
    return {'id': id, 'categoryName': categoryName, 'parentId': parentId};
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category()
      ..id = json['id'] as String
      ..categoryName = json['categoryName'] as String
      ..parentId = json['parentId'] as String?;
  }
}
