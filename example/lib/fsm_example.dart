import 'package:fsm2/fsm2.dart';

void main() {
  final machine = StateMachine.create((g) => g
    ..initialState<Solid>()
    ..state<Solid>((b) => b
      ..onDynamic<OnMelted>((s, e) => b.transitionTo<Liquid>(
            sideEffect: () => print('Melted'),
          )))
    ..state<Liquid>((b) => b
      ..onEnter((s, e) => print('Entering ${s.runtimeType} State'))
      ..onExit((s, e) => print('Exiting ${s.runtimeType} State'))
      ..onDynamic<OnFroze>((s, e) => b.transitionTo<Solid>(
            sideEffect: () => print('Frozen'),
          ))
      ..onDynamic<OnVaporized>((s, e) => b.transitionTo<Gas>(
            sideEffect: () => print('Vaporized'),
          )))
    ..state<Gas>((b) => b
      ..onDynamic<OnCondensed>((s, e) => b.transitionTo<Liquid>(
            sideEffect: () => print('Condensed'),
          )))
    ..onTransition((t) => print(
        'Recieved Event ${t.eventType} in State ${t.fromState.runtimeType} transitioning to State ${t.toState.runtimeType}')));

  print(machine.currentState is Solid); // TRUE

  machine.transition(OnMelted());
  print(machine.currentState is Liquid); // TRUE

  machine.transition(OnFroze());
  print(machine.currentState is Solid); // TRUE
}

class Solid implements State {}

class Liquid implements State {}

class Gas implements State {}

class OnMelted implements Event {}

class OnFroze implements Event {}

class OnVaporized implements Event {}

class OnCondensed implements Event {}
