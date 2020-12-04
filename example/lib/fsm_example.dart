import 'package:fsm2/fsm2.dart';

void main() async {
  final machine = StateMachine.create((g) => g
    ..initialState<Solid>()
    ..state<Solid>((b) => b
      ..on<OnMelted, Liquid>(sideEffect: () async => print('Melted'))
      ..onEnter((s, e) async => print('Entering ${s} State'))
      ..onExit((s, e) async => print('Exiting ${s} State')))
    ..state<Liquid>((b) => b
      ..onEnter((s, e) async => print('Entering ${s} State'))
      ..onExit((s, e) async => print('Exiting ${s} State'))
      ..on<OnFroze, Solid>(sideEffect: () async => print('Frozen'))
      ..on<OnVaporized, Gas>(sideEffect: () async => print('Vaporized')))
    ..state<Gas>((b) => b
      ..onEnter((s, e) async => print('Entering ${s} State'))
      ..onExit((s, e) async => print('Exiting ${s} State'))
      ..on<OnCondensed, Liquid>(sideEffect: () async => print('Condensed')))
    ..onTransition((from, e, to) =>
        print('Recieved Event ${e} in State ${from.stateType} transitioning to State ${to.stateType}')));

  machine.analyse();
  machine.export('test/test.gv');

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
