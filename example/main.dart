import 'dart:developer';

import 'package:fsm2/fsm2.dart';

void main() {
  final machine = StateMachine.create((g) => g
    ..initialState<Solid>()
    ..state<Solid>((b) => b
      ..on<OnMelted, Liquid>(sideEffect: () async => log('Melted'))
      ..onEnter((s, e) async => log('Entering $s State'))
      ..onExit((s, e) async => log('Exiting $s State')))
    ..state<Liquid>((b) => b
      ..onEnter((s, e) async => log('Entering $s State'))
      ..onExit((s, e) async => log('Exiting $s State'))
      ..on<OnFroze, Solid>(sideEffect: () async => log('Frozen'))
      ..on<OnVaporized, Gas>(sideEffect: () async => log('Vaporized')))
    ..state<Gas>((b) => b
      ..onEnter((s, e) async => log('Entering $s State'))
      ..onExit((s, e) async => log('Exiting $s State'))
      ..on<OnCondensed, Liquid>(sideEffect: () async => log('Condensed')))
    ..onTransition((from, e, to) => log(
        'Recieved Event $e in State ${from.stateType} transitioning to State ${to.stateType}')));

  machine.analyse();
  machine.export('test/smcat/water.smcat');

  machine.applyEvent(OnMelted());

  machine.applyEvent(OnFroze());
}

class Solid implements State {}

class Liquid implements State {}

class Gas implements State {}

class OnMelted implements Event {}

class OnFroze implements Event {}

class OnVaporized implements Event {}

class OnCondensed implements Event {}
