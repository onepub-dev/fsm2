import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';

void main() {
  late StateMachine fsm;

  /// https://github.com/onepub-dev/fsm2/issues/18
  test('test fork join with sideEffect', () async {
    fsm = await StateMachine.create(
        (g) => g
          ..initialState<CanFork>()
          ..state<CanFork>((b) => b.onFork<Fork>(
              (b) => b
                ..target<StateA>()
                ..target<StateB>(),
              sideEffect: (e) async => fsm.applyEvent(ResolveStateA())))
          ..coregion<Coregion>((b) => b
            ..state<StateA>((b) => b.onJoin<ResolveStateA, EndState>())
            ..state<StateB>((b) => b.onJoin<ResolveStateB, EndState>()))
          ..state<EndState>((b) => b.on<GoBackToStart, CanFork>()),
        production: true)
      // go into the coregion
      ..applyEvent(Fork());
    await fsm.complete;
    // we are now in the coregion
    expect(await fsm.isInState<Coregion>(), equals(true),
        reason: fsm.stateOfMind.toString());
    // StateA is already resolved by the sideEffect.
    // StateB is not resolved yet.
    fsm.applyEvent(ResolveStateB());
    await fsm.complete;
    // we are now at the end state.
    expect(await fsm.isInState<EndState>(), equals(true),
        reason: fsm.stateOfMind.toString());
    // go back to the start.
    fsm.applyEvent(GoBackToStart());
    await fsm.complete;
    expect(await fsm.isInState<CanFork>(), equals(true),
        reason: fsm.stateOfMind.toString());
    // go into the coregion again.
    fsm.applyEvent(Fork());
    await fsm.complete;
    // if the coregion does not reset the join events, we will fail here.
    expect(await fsm.isInState<Coregion>(), equals(true),
        reason: fsm.stateOfMind.toString());
    fsm.applyEvent(ResolveStateB());
    await fsm.complete;
    expect(await fsm.isInState<EndState>(), equals(true),
        reason: fsm.stateOfMind.toString());
  });
}

class CanFork extends State {}

class Fork extends Event {}

class Coregion extends State {}

class StateA extends State {}

class ResolveStateA extends Event {}

class StateB extends State {}

class ResolveStateB extends Event {}

class EndState extends State {}

class GoBackToStart extends Event {}
