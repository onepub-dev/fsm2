import 'package:dfunc/dfunc.dart';
import 'package:fsm/fsm.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

part 'fsm_test.g.dart';

@Sealed()
abstract class State with SealedState {}

class Solid extends State {}

class Liquid extends State {}

class Gas extends State {}

@Sealed()
abstract class Event with SealedEvent {}

class OnMelted extends Event {}

class OnFroze extends Event {}

class OnVaporized extends Event {}

class OnCondensed extends Event {}

@Sealed()
abstract class SideEffect with SealedSideEffect {}

class LogMelted extends SideEffect {}

class LogFrozen extends SideEffect {}

class LogVaporized extends SideEffect {}

class LogCondensed extends SideEffect {}

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

  test('initial state should be solid', () {
    final machine = _createMachine(Solid(), watcher);
    expect(machine.currentState, isA<Solid>());
  });

  test('state Solid with OnMelted should transition to Liquid and log', () {
    final machine = _createMachine(Solid(), watcher);
    machine.transition(OnMelted());
    expect(machine.currentState, isA<Liquid>());
    verifyInOrder([watcher.log(onMeltedMessage)]);
  });

  test('state Liquid with OnFroze should transition to Solid and log', () {
    final machine = _createMachine(Liquid(), watcher);
    machine.transition(OnFroze());
    expect(machine.currentState, isA<Solid>());
    verifyInOrder([watcher.log(onFrozenMessage)]);
  });

  test('state Liquid with OnVaporized should transition to Gas and log', () {
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

StateMachine<State, Event, SideEffect> _createMachine(
  State initialState,
  Watcher watcher,
) =>
    StateMachine<State, Event, SideEffect>.create((g) => g
      ..initialState(initialState)
      ..state<Solid>((b) =>
          b..on<OnMelted>((s, e) => b.transitionTo(Liquid(), LogMelted())))
      ..state<Liquid>((b) => b
        ..onEnter((s) => watcher?.onEnter(s.runtimeType))
        ..onExit((s) => watcher?.onExit(s.runtimeType))
        ..on<OnFroze>((s, e) => b.transitionTo(Solid(), LogFrozen()))
        ..on<OnVaporized>((s, e) => b.transitionTo(Gas(), LogVaporized())))
      ..state<Gas>((b) => b
        ..on<OnCondensed>((s, e) => b.transitionTo(Liquid(), LogCondensed())))
      ..onTransition((t) => t.match((v) {
            final message = v.sideEffect?.match(
              always(onMeltedMessage),
              always(onFrozenMessage),
              always(onVaporizedMessage),
              always(onCondensedMessage),
            );
            if (message != null) watcher.log(message);
          }, ignore)));

const onMeltedMessage = 'onMeltedMessage';
const onFrozenMessage = 'onFrozenMessage';
const onVaporizedMessage = 'onVaporizedMessage';
const onCondensedMessage = 'onCondensedMessage';
