import 'package:mood_diary/utils/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserState {
  late User? user = Utils().supabaseUtil.user;

  late Session? session = Utils().supabaseUtil.session;

  UserState() {
    ///Initialize variables
  }
}
