A library for finite state machine realization in Dart. Inspired by [Tinder StateMachine library](https://github.com/Tinder/StateMachine).

## Usage

A simple usage example (using [dfunc](https://pub.dev/packages/dfunc) library for generating sealed classes):

```dart
import 'package:dfunc/dfunc.dart';
import 'package:fsm/fsm.dart';

part 'fsm_example.g.dart';

void main() {
  final machine = StateMachine<State, Event, SideEffect>.create((g) => g
    ..initialState(Solid())
    ..state<Solid>((b) => b
      ..on<OnMelted>(
          (Solid s, OnMelted e) => b.transitionTo(Liquid(), LogMelted())))
    ..state<Liquid>((b) => b
      ..onEnter((s) => print('Entering ${s.runtimeType} state'))
      ..onExit((s) => print('Exiting ${s.runtimeType} state'))
      ..on<OnFroze>(
          (Liquid s, OnFroze e) => b.transitionTo(Solid(), LogFrozen()))
      ..on<OnVaporized>(
          (Liquid s, OnVaporized e) => b.transitionTo(Gas(), LogVaporized())))
    ..state<Gas>((b) => b
      ..on<OnCondensed>(
          (Gas s, OnCondensed e) => b.transitionTo(Liquid(), LogCondensed())))
    ..onTransition((t) => t.match((v) => print(v.sideEffect), (_) {})));

  print(machine.currentState is Solid); // TRUE

  machine.transition(OnMelted());
  print(machine.currentState is Liquid); // TRUE

  machine.transition(OnFroze());
  print(machine.currentState is Solid); // TRUE
}

@sealed
abstract class State with _$State {}

class Solid extends State {}

class Liquid extends State {}

class Gas extends State {}

@sealed
abstract class Event with _$Event {}

class OnMelted extends Event {}

class OnFroze extends Event {}

class OnVaporized extends Event {}

class OnCondensed extends Event {}

@sealed
abstract class SideEffect with _$SideEffect {}

class LogMelted extends SideEffect {}

class LogFrozen extends SideEffect {}

class LogVaporized extends SideEffect {}

class LogCondensed extends SideEffect {}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/ookami-kb/fsm/issues
