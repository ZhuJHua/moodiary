import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:moodiary_logging/moodiary_logging.dart';

void main() {
  tearDown(AppLogger.debugReset);

  List<String?> record() {
    final calls = <String?>[];
    AppLogger.loggerFactory = (path) {
      calls.add(path);
      return Logger(output: ConsoleOutput(), filter: ProductionFilter());
    };
    return calls;
  }

  test('configure 晚于首条日志：下一条起按新路径重建', () {
    final calls = record();
    logger.i('before configure');
    expect(calls, [null], reason: '首条日志用未配置路径构建');

    AppLogger.configure(logFilePath: '/tmp/moodiary-test/a.log');
    logger.i('after configure');
    expect(calls, [
      null,
      '/tmp/moodiary-test/a.log',
    ], reason: 'configure 必须失效缓存，下一条日志重建');
  });

  test('未 configure 期间不重复重建', () {
    final calls = record();
    logger.i('one');
    logger.i('two');
    expect(calls, [null], reason: 'Logger 实例被缓存，不逐条重建');
  });
}
