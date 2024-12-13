import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/data/supabase.dart';

class UserState {
  late User? user = SupabaseUtil().user;

  late Session? session = SupabaseUtil().session;

  UserState() {
    ///Initialize variables
  }
}
