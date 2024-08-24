import 'dart:convert';

class ArrayUtil {
  //统计列表元素出现次数
  Map<T, int> countList<T>(List<T> list) {
    Map<T, int> counts = {};
    for (var item in list) {
      counts[item] = counts.containsKey(item) ? counts[item]! + 1 : 1;
    }
    return counts;
  }

  //统计列表元素总长度
  int countListItemLength(List<String> list) {
    return list.fold(0, (sum, content) => sum + content.length);
  }

  //列表去重
  List<T> toSetList<T>(List<T> list) {
    return list.toSet().toList();
  }

  //将 List<String> 转换为字符串
  String listToString(List<String> list) {
    return jsonEncode(list);
  }

  //将字符串转换为 List<String>
  List<String> stringToList(String jsonString) {
    return jsonDecode(jsonString).cast<String>();
  }
}
