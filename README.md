
FSM2 provides an implementation of the core design aspects of the UML2 state diagrams.

FMS2 supports:
* Nested States
* Concurrent Regions
* Guard Conditions
* sideEffects
* onEnter/onExit
* streams
* static analysis tools
* visualisation tools.


# Overview
FSM2 uses a builder to delcare each state machine.

Your application may declare as many statemachines as necessary.

## Example

```dart
import 'package:fsm2/fsm2.dart';

void main() {
  final machine = StateMachine.create((g) => g
    ..initialState(Solid())
    ..state<Solid>((b) => b
      ..on<OnMelted, Liquid>(), sideEffect: (e) => print("I'm melting"))
    ..state<Liquid>((b) {})
 ));

```

The above examples creates a Finite State Machine (machine) which declares its initial state as being `Solid` and then declares a single
transition which occurs when the event `OnMelted` event is triggered causing a transition to a new state `Liquid`.

To trigger an event:

```dart
machine.applyEvent(OnMelted());
```

# Documentation
Full documentation is available on gitbooks at:

https://bsutton.gitbook.io/fsm2/



## Example 2
A simple example showing the life cycle of H2O.


```dart
import 'package:fsm2/fsm2.dart';

void main() {
  final machine = StateMachine.create((g) => g
    ..initialState(Solid())
    ..state<Solid>((b) => b
      ..on<OnMelted, Liquid>(sideEffect: (e) => print('Melted'),
          )))
    ..state<Liquid>((b) => b
      ..onEnter((s, e) => print('Entering ${s.runtimeType} State'))
      ..onExit((s, e) => print('Exiting ${s.runtimeType} State'))
      ..on<OnFroze, Solid>(sideEffect: (e) => print('Frozen')))
      ..on<OnVaporized, Gas>(sideEffect: (e) => print('Vaporized'))))
    ..state<Gas>((b) => b
      ..on<OnCondensed, Liquid>(sideEffect: (e) => print('Condensed'))))
    ..onTransition((t) => print(
        'Recieved Event ${t.event.runtimeType} in State ${t.fromState.runtimeType} transitioning to State ${t.toState.runtimeType}')));

  print(machine.currentState is Solid); // TRUE

  machine.transition(OnMelted());
  print(machine.currentState is Liquid); // TRUE

  machine.transition(OnFroze());
  print(machine.currentState is Solid); // TRUE
}

```

# Credits:

FMS2 is derived from the FSM library which in turn was inspired by [Tinder StateMachine library](https://github.com/Tinder/StateMachine).