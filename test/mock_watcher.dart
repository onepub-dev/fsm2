import 'package:fsm2/src/types.dart';
import 'package:mockito/mockito.dart';

class MockWatcher extends Mock {
  Future<void> onEnter(Type t, Event e);

  Future<void> onExit(Type t, Event e);

  void log(String message);
}
