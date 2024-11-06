import 'package:mood_diary/utils/utils.dart';

class RemovePasswordState {
  String password = '';

  String realPassword = Utils().prefUtil.getValue<String>('password')!;

  RemovePasswordState();
}
