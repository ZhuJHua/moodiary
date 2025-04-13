import 'package:moodiary/persistence/pref.dart';

class RemovePasswordState {
  String password = '';

  String realPassword = PrefUtil.getValue<String>('password')!;

  RemovePasswordState();
}
