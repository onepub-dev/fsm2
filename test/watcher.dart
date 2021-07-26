// http_server_test.dart:
import 'package:fsm2/src/types.dart';

/// We uses this class to help verify that specific calls
/// are made when the fsm is running.
/// See https://github.com/dart-lang/mockito/blob/master/NULL_SAFETY_README.md
/// for details on how we use this class to generate the MockWatcher class
/// usin code generation.
class Watcher {
  Future<void> onEnter(Type t, Event e) async {}

  Future<void> onExit(Type t, Event e) async {}

  void log(String message) {}
}
