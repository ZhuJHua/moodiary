import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/utils/task_scheduler.dart';

void main() {
  group('TaskScheduler', () {
    test('should execute tasks and return correct results', () async {
      final scheduler = TaskScheduler(2);

      final result1 = scheduler.add(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'Task 1 completed';
      });

      final result2 = scheduler.add(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'Task 2 completed';
      });

      expect(await result1, equals('Task 1 completed'));
      expect(await result2, equals('Task 2 completed'));
    });

    test('should not exceed max concurrent tasks', () async {
      final scheduler = TaskScheduler(2);
      int runningTasks = 0;
      final List<int> concurrentCounts = [];

      Future<void> task() async {
        runningTasks++;
        concurrentCounts.add(runningTasks);
        await Future.delayed(const Duration(milliseconds: 100));
        runningTasks--;
      }

      await Future.wait([
        scheduler.add(task),
        scheduler.add(task),
        scheduler.add(task),
        scheduler.add(task),
      ]);

      expect(concurrentCounts.reduce((a, b) => a > b ? a : b),
          lessThanOrEqualTo(2));
    });

    test('tasks should execute in order', () async {
      final scheduler = TaskScheduler(1);
      final List<String> executionOrder = [];

      await Future.wait([
        scheduler.add(() async {
          await Future.delayed(const Duration(milliseconds: 50));
          executionOrder.add('Task 1');
        }),
        scheduler.add(() async {
          await Future.delayed(const Duration(milliseconds: 50));
          executionOrder.add('Task 2');
        }),
        scheduler.add(() async {
          await Future.delayed(const Duration(milliseconds: 50));
          executionOrder.add('Task 3');
        }),
      ]);

      expect(executionOrder, equals(['Task 1', 'Task 2', 'Task 3']));
    });

    test('should handle task errors correctly', () async {
      final scheduler = TaskScheduler(2);

      Future<void> failingTask() async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw Exception('Task failed');
      }

      expect(scheduler.add(failingTask), throwsException);
    });
  });
}
