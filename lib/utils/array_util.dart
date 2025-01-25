import 'dart:convert';

class ArrayUtil {
  //统计列表元素出现次数
  static Map<T, int> countList<T>(List<T> list) {
    final Map<T, int> counts = {};
    for (final item in list) {
      counts[item] = counts.containsKey(item) ? counts[item]! + 1 : 1;
    }
    return counts;
  }

  //统计列表元素总长度
  static int countListItemLength(List<String> list) {
    return list.fold(0, (sum, content) => sum + content.length);
  }

  //列表去重
  static List<T> toSetList<T>(List<T> list) {
    return list.toSet().toList();
  }

  //将 List<String> 转换为字符串
  static String listToString(List<String> list) {
    return jsonEncode(list);
  }

  //将字符串转换为 List<String>
  static List<String> stringToList(String jsonString) {
    return jsonDecode(jsonString).cast<String>();
  }
}
