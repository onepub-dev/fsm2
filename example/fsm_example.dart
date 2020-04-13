import 'package:dfunc/dfunc.dart';
import 'package:fsm/fsm.dart';

part 'fsm_example.g.dart';

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
