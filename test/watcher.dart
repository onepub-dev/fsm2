import 'package:fsm2/src/types.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([Watcher])
class Watcher {
  Future<void> onEnter(Type t, Event? e) {
    return Future.value();
  }

  Future<void> onExit(Type t, Event? e) {
    return Future.value();
  }

  void log(String message) {}
}
