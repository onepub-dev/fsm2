import 'package:fsm2/fsm2.dart';

void main() async {
  final machine = StateMachine.create((g) => g
    ..initialState<Solid>()
    ..state<Solid>((b) => b..on<OnMelted, Liquid>(sideEffect: () async => print('Melted')))
    ..state<Liquid>((b) => b
      ..onEnter((s, e) async => print('Entering ${s.runtimeType} State'))
      ..onExit((s, e) async => print('Exiting ${s.runtimeType} State'))
      ..on<OnFroze, Solid>(sideEffect: () async => print('Frozen'))
      ..on<OnVaporized, Gas>(sideEffect: () async => print('Vaporized')))
    ..state<Gas>((b) => b..on<OnCondensed, Liquid>(sideEffect: () async => print('Condensed')))
    ..onTransition((from, e, to) =>
        print('Recieved Event ${e} in State ${from.stateType} transitioning to State ${to.stateType}')));

  await machine.analyse();
  await machine.export('test/test.gv');

  print(machine.isInState<Solid>()); // TRUE

  await machine.applyEvent(OnMelted());
  print(machine.isInState<Liquid>()); // TRUE

  await machine.applyEvent(OnFroze());
  print(machine.isInState<Solid>()); // TRUE
}

class Solid implements State {}

class Liquid implements State {}

class Gas implements State {}

class OnMelted implements Event {}

class OnFroze implements Event {}

class OnVaporized implements Event {}

class OnCondensed implements Event {}
