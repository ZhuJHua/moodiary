import 'dart:async';
import 'dart:collection';

class TaskScheduler {
  final int maxConcurrentTasks;
  final Queue<_Task> _taskQueue = Queue();
  int _runningTasks = 0;

  TaskScheduler(this.maxConcurrentTasks);

  Future<T> add<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _taskQueue.add(_Task(task, completer));
    _runNext();
    return completer.future;
  }

  void _runNext() {
    if (_runningTasks < maxConcurrentTasks && _taskQueue.isNotEmpty) {
      _runningTasks++;
      final task = _taskQueue.removeFirst();
      task.run().whenComplete(() {
        _runningTasks--;
        _runNext();
      });
    }
  }
}

class _Task<T> {
  final Future<T> Function() task;
  final Completer<T> completer;

  _Task(this.task, this.completer);

  Future<void> run() async {
    try {
      final result = await task();
      completer.complete(result);
    } catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
    }
  }
}
