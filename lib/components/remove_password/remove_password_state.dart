import '../../utils/data/pref.dart';

class RemovePasswordState {
  String password = '';

  String realPassword = PrefUtil.getValue<String>('password')!;

  RemovePasswordState();
}
