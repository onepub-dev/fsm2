import 'package:fsm2/fsm2.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class Solid implements State {}

class Liquid implements State {}

class Gas implements State {}

class OnMelted implements Event {}

class OnFroze implements Event {}

class OnVaporized implements Event {}

class OnCondensed implements Event {}

class Watcher extends Mock {
  void onEnter(Type t);

  void onExit(Type t);

  void log(String message);
}

void main() {
  Watcher watcher;

  setUp(() {
    watcher = Watcher();
  });

  test('initial State should be solid', () {
    final machine = _createMachine(Solid(), watcher);
    expect(machine.currentState, isA<Solid>());
  });

  test('State Solid with OnMelted should transition to Liquid and log', () {
    final machine = _createMachine(Solid(), watcher);
    machine.transition(OnMelted());
    expect(machine.currentState, isA<Liquid>());
    verifyInOrder([watcher.log(onMeltedMessage)]);
  });

  test('State Liquid with OnFroze should transition to Solid and log', () {
    final machine = _createMachine(Liquid(), watcher);
    machine.transition(OnFroze());
    expect(machine.currentState, isA<Solid>());
    verifyInOrder([watcher.log(onFrozenMessage)]);
  });

  test('State Liquid with OnVaporized should transition to Gas and log', () {
    final machine = _createMachine(Liquid(), watcher);
    machine.transition(OnVaporized());
    expect(machine.currentState, isA<Gas>());
    verifyInOrder([watcher.log(onVaporizedMessage)]);
  });

  test('calls onEnter, but not onExit', () {
    final watcher = Watcher();
    final machine = _createMachine(Solid(), watcher);
    machine.transition(OnMelted());
    verify(watcher.onEnter(Liquid));
    verifyNever(watcher.onExit(Liquid));
  });

  test('calls onExit', () {
    final watcher = Watcher();
    final machine = _createMachine(Solid(), watcher);
    machine.transition(OnMelted());
    machine.transition(OnVaporized());
    verify(watcher.onExit(Liquid));
  });
}

StateMachine _createMachine(
  State initialState,
  Watcher watcher,
) =>
    StateMachine.create((g) => g
          ..initialState(initialState)
          ..state<Solid>((b) =>
              b..on<OnMelted>((s, e) => b.transitionTo(Liquid(), sideEffect: () => watcher.log(onMeltedMessage))))
          ..state<Liquid>((b) => b
            ..onEnter((s, e) => watcher?.onEnter(s.runtimeType))
            ..onExit((s, e) => watcher?.onExit(s.runtimeType))
            ..on<OnFroze>((s, e) => b.transitionTo(Solid(), sideEffect: () => watcher.log(onFrozenMessage)))
            ..on<OnVaporized>((s, e) => b.transitionTo(Gas(), sideEffect: () => watcher.log(onVaporizedMessage))))
          ..state<Gas>((b) =>
              b..on<OnCondensed>((s, e) => b.transitionTo(Liquid(), sideEffect: () => watcher.log(onCondensedMessage))))
        // ..onTransition((t) => onTransition(watcher, t))
        );

const onMeltedMessage = 'onMeltedMessage';
const onFrozenMessage = 'onFrozenMessage';
const onVaporizedMessage = 'onVaporizedMessage';
const onCondensedMessage = 'onCondensedMessage';
