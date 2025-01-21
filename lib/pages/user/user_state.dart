import 'package:moodiary/utils/data/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserState {
  late User? user = SupabaseUtil().user;

  late Session? session = SupabaseUtil().session;

  UserState() {
    ///Initialize variables
  }
}
