// Utility to run a function in a background isolate and return its result.
// Supports a single argument function that returns a value of type T.
// Usage: final runner = IsolateRunner();
// final result = await runner.run<T>(() => heavyFunction(arg));

import 'dart:isolate';

class IsolateRunner {
  /// Runs the provided synchronous function [fn] in a new isolate.
  /// Returns a [Future] that completes with the function's return value.
  /// Errors thrown inside the isolate are rethrown to the caller.
  Future<T> run<T>(T Function() fn) async {
    // Create a ReceivePort for communication.
    final responsePort = ReceivePort();
    // The entry point for the isolate.
    void entryPoint(List<dynamic> args) {
      final SendPort sendPort = args[0];
      final T Function() function = args[1];
      try {
        final result = function();
        sendPort.send(_IsolateResult<T>(result: result));
      } catch (e, st) {
        sendPort.send(_IsolateResult<T>(error: e, stackTrace: st));
      }
    }

    // Spawn isolate.
    await Isolate.spawn(entryPoint, [responsePort.sendPort, fn]);

    // Await first message.
    final _IsolateResult<T> result = await responsePort.first;
    responsePort.close();
    if (result.error != null) {
      // Re‑throw preserving stack trace.
      // ignore: only_throw_errors
      throw result.error!;
    }
    return result.result as T;
  }
}

class _IsolateResult<T> {
  final T? result;
  final Object? error;
  final StackTrace? stackTrace;
  _IsolateResult({this.result, this.error, this.stackTrace});
}
