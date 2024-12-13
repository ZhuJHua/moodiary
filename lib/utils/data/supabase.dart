import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/utils/data/pref.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUtil {
  late final SupabaseClient _supabase = Supabase.instance.client;

  Session? get session => _supabase.auth.currentSession;

  User? get user => _supabase.auth.currentUser;

  SupabaseUtil._();

  static final SupabaseUtil _instance = SupabaseUtil._();

  factory SupabaseUtil() => _instance;

  Future<void> initSupabase() async {
    if (PrefUtil.getValue<bool>('firstStart') == false) {
      await Supabase.initialize(
        url: '',
        anonKey: '',
      );
    }
  }

  //注册
  Future<void> signUp(String email, String password) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
    );
    await _supabase.from('test').select('*');
  }

  Future<void> uploadDiary(List<Diary> diaryList) async {
    var u = _supabase.auth.currentUser;
    //User不为空说明已经登录
    if (u != null) {
      //插入数据库时加一个UserID字段作为唯一标识
      await _supabase.from('diary').insert(List.generate(diaryList.length, (index) {}));
    }
  }

  Future<List<Map<String, dynamic>>> getData() async {
    return await _supabase.from('diary').select('*');
  }

  //登录
  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  //退出登录
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
