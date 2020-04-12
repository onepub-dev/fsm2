import 'package:fsm/fsm.dart';
import 'package:test/test.dart';

abstract class State {}

class Solid extends State {}

class Liquid extends State {}

class Gas extends State {}

abstract class Event {}

class OnMelted extends Event {}

class OnFroze extends Event {}

class OnVaporized extends Event {}

class OnCondensed extends Event {}

abstract class SideEffect {}

class LogMelted extends SideEffect {}

class LogFrozen extends SideEffect {}

class LogVaporized extends SideEffect {}

class LogCondensed extends SideEffect {}

void main() {
  test('initial state should be solid', () {
    final machine = _createMachine(Solid());
    expect(machine.state, isA<Solid>());
  });

  test('given state Solid with OnMelted should transition to Liquid', () {
    final machine = _createMachine(Solid());
    machine.transition(OnMelted());
    expect(machine.state, isA<Liquid>());
  });

  test('given state Liquid with OnFroze should transition to Solid', () {
    final machine = _createMachine(Liquid());
    machine.transition(OnFroze());
    expect(machine.state, isA<Solid>());
  });

  test('given state Liquid with OnVaporized should transition to Gas', () {
    final machine = _createMachine(Liquid());
    machine.transition(OnVaporized());
    expect(machine.state, isA<Gas>());
  });
}

StateMachine<State, Event, SideEffect> _createMachine(State initialState) =>
    StateMachine<State, Event, SideEffect>.create((g) => g
      ..initialState(initialState)
      ..state<Solid>((b) =>
          b..on<OnMelted>((s, e) => b.transitionTo(Liquid(), LogMelted())))
      ..state<Liquid>((b) => b
        ..on<OnFroze>((s, e) => b.transitionTo(Solid(), LogFrozen()))
        ..on<OnVaporized>((s, e) => b.transitionTo(Gas(), LogVaporized())))
      ..state<Gas>((b) => b
        ..on<OnCondensed>((s, e) => b.transitionTo(Liquid(), LogCondensed()))));
