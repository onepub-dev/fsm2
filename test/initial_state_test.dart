import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';

import 'watcher.mocks.dart';

void main() {
  test('initialState for abstract states', () async {
    final watcher = MockWatcher();
    try {
      await createMachine(watcher);
    } on InvalidStateMachine catch (e) {
      expect(e.toString(), contains('Check logs'));
    }
  }, skip: false);
}

Future<StateMachine> createMachine(MockWatcher watcher) async {
  final machine = await StateMachine.create((g) => g
    ..initialState<ParentState>()
    ..state<ParentState>((b) => b
      ..initialState<ChildStateA>()
      ..on<GoToStateA, ChildStateA>()
      ..on<GoToStateB, ChildStateB>()
      ..state<ChildStateA>((b) => b)
      ..state<ChildStateB>((b) => b
        ..initialState<ChildStateC>()
        ..on<GoToStateC, ChildStateC>()
        ..state<ChildStateC>((b) => b))));

  return machine;
}

class ParentState extends State {}

class ChildStateA extends State {}

class ChildStateB extends State {}

class ChildStateC extends State {}

class GoToStateA extends Event {}

class GoToStateB extends Event {}

class GoToStateC extends Event {}
