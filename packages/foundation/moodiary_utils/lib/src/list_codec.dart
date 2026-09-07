import 'dart:convert';

class ListCodec {
  static Map<T, int> countList<T>(List<T> list) {
    final Map<T, int> counts = {};
    for (final item in list) {
      counts[item] = counts.containsKey(item) ? counts[item]! + 1 : 1;
    }
    return counts;
  }

  static int countListItemLength(List<String> list) {
    return list.fold(0, (sum, content) => sum + content.length);
  }

  static List<T> toSetList<T>(List<T> list) {
    return list.toSet().toList();
  }

  static String listToString(List<String> list) {
    return jsonEncode(list);
  }

  static List<String> stringToList(String jsonString) {
    return jsonDecode(jsonString).cast<String>();
  }
}
