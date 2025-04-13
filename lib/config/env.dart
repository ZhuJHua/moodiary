class Env {
  static String appMode = const String.fromEnvironment(
    'APP_MODE',
    defaultValue: 'release',
  );

  static bool get debugMode => appMode == 'debug';
}
