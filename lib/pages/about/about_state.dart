import 'package:get/get.dart';

class AboutState {
  late RxString appName;

  late RxString appVersion;

  AboutState() {
    appName = ''.obs;
    appVersion = ''.obs;
  }
}
