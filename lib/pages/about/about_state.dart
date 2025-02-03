import 'package:refreshed/refreshed.dart';

class AboutState {
  String appName = '';

  String appVersion = '';
  String systemVersion = '';
  RxBool isFetching = true.obs;

  AboutState();
}
