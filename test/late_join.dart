import 'package:fsm2/fsm2.dart';
import 'package:fsm2/src/types.dart';
import 'package:test/test.dart';

import 'watcher.mocks.dart';

void main() {
  test('late join', () async {
    final watcher = MockWatcher();
    final machine = createMachine(watcher);

    expect(machine.isInState<Idle>(), isTrue);

    machine.applyEvent(OnFocus());
    machine.applyEvent(const OnValueChange(isFormula: true));
    await machine.waitUntilQuiescent;

    expect(machine.isInState<TypingFormula>(), isTrue);

    machine.applyEvent(const OnValueChange(isFormula: false));
    await machine.waitUntilQuiescent;

    expect(machine.isInState<Typing>(), isTrue);
    expect(machine.isInState<TypingFormula>(), isFalse);
  }, skip: false);
}

class TypingFormula implements State {}

class Typing implements State {}

class Idle implements State {}

StateMachine createMachine(MockWatcher watcher) {
  final machine = StateMachine.create((g) => g
    ..initialState<Idle>()
    ..state<Idle>((b) => b..on<OnFocus, Typing>())
    ..state<Typing>((b) => b
      ..on<OnBlur, Idle>()
      ..onFork<OnValueChange>((b) => b..target<Point>()..target<Autocomplete>(),
          condition: (e) => e.isFormula)
      ..coregion<TypingFormula>((b) => b
        ..onJoin<OnValueChange, Typing>(condition: (e) => !e.isFormula)

        // Autocomplete state machine
        ..state<Autocomplete>((b) => b)
        // Point mode state-mahcine
        ..state<Point>((b) => b)))
    // ignore: avoid_print
    ..onTransition((from, e, to) => print(
        'Received Event $e in State ${from!.stateType} transitioning to State ${to!.stateType}')));

  return machine;
}

class Point extends State {}

class Autocomplete extends State {}

class OnBlur extends Event {}

class OnFocus extends Event {}

class OnValueChange implements Event {
  final bool isFormula;
  const OnValueChange({required this.isFormula});
}
