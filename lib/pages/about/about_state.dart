import 'package:get/get.dart';

class AboutState {
  String appName = '';

  String appVersion = '';
  String systemVersion = '';
  RxBool isFetching = true.obs;

  AboutState();
}
