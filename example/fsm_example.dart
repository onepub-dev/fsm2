import 'package:fsm/fsm.dart';

void main() {
  final machine = StateMachine<State, Event, SideEffect>.create((g) => g
    ..initialState(Solid())
    ..state<Solid>(
        (b) => b..on<OnMelted>((s, e) => b.transitionTo(Liquid(), LogMelted())))
    ..state<Liquid>((b) => b
      ..on<OnFroze>((s, e) => b.transitionTo(Solid(), LogFrozen()))
      ..on<OnVaporized>((s, e) => b.transitionTo(Gas(), LogVaporized())))
    ..state<Gas>((b) =>
        b..on<OnCondensed>((s, e) => b.transitionTo(Liquid(), LogCondensed())))
    ..onTransition((t) => t.match((v) => print(v.sideEffect), (_) {})));

  print(machine.currentState is Solid); // TRUE

  machine.transition(OnMelted());
  print(machine.currentState is Liquid); // TRUE
}

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
