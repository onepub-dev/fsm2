@Timeout(Duration(minutes: 30))
import 'package:fsm2/fsm2.dart';
import 'package:fsm2/src/types.dart';
import 'package:test/test.dart';

StateMachine createMachine() {
  final machine = StateMachine.create(
    (g) => g
      ..initialState<Start>()
      ..state<Start>((g) => g..on<OnKickStart, Main>())
      ..state<Main>(
        (g) => g
          ..on<OnTickFirst, First>()
          ..on<OnTickSecond, Second>()
          ..coregion<First>(
            (g) => g
              ..initialState<One>()
              ..state<One>((g) => g..on<OnToggle, Two>())
              ..state<Two>((g) => g..on<OnToggle, One>()),
          )
          ..coregion<Second>(
            (g) => g
              ..initialState<Three>()
              ..state<Three>((g) => g..on<OnToggle, Four>())
              ..state<Four>((g) => g..on<OnToggle, Three>()),
          ),
      ),
  );
  return machine;
}

class OnKickStart implements Event {}

class Main implements State {}

class Start implements State {}

class First implements State {}

class Second implements State {}

class One implements State {}

class Two implements State {}

class Three implements State {}

class Four implements State {}

class OnTickFirst implements Event {}

class OnTickSecond implements Event {}

class OnToggle implements Event {}

void main() {
  test('should properly define initial state', () async {
    final machine = createMachine();
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Start>(), equals(true));
  });

  test('should transition to intial state of nested machine', () async {
    final machine = createMachine();
    await machine.waitUntilQuiescent;

    machine.applyEvent(OnKickStart());
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Main>(), equals(true));

    machine.applyEvent(OnTickFirst());
    await machine.waitUntilQuiescent;
    expect(machine.isInState<First>(), equals(true));
    expect(machine.isInState<One>(), equals(true));
  });

  test(
    'should reset navigate back to initial state if transition to state '
    'machine again',
    () async {
      final machine = createMachine();
      await machine.waitUntilQuiescent;

      expect(machine.isInState<Main>(), equals(true));

      machine.applyEvent(OnTickFirst());
      await machine.waitUntilQuiescent;
      expect(machine.isInState<First>(), equals(true));
      expect(machine.isInState<One>(), equals(true));

      machine.applyEvent(OnToggle());
      await machine.waitUntilQuiescent;
      expect(machine.isInState<First>(), equals(true));
      expect(machine.isInState<Two>(), equals(true));

      machine.applyEvent(OnTickFirst());
      await machine.waitUntilQuiescent;
      expect(machine.isInState<First>(), equals(true));
      expect(machine.isInState<One>(), equals(true));
    },
  );
}
