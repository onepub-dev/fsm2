import 'package:fsm2/fsm2.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class Watcher extends Mock {
  OnEnter onEnter;

  OnExit onExit;

  void log(String message);
}

void main() {
  Watcher watcher;
  Human human;

  setUp(() {
    watcher = Watcher();
    human = Human();
  });

  test('initial State should be Alive', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    expect(machine.isInState<Alive>(), equals(true));
  });

  test('State Alive with OnBirthday should transition to Young and log', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    await machine.transition(OnBirthday());
    expect(machine.isInState<Young>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('State Liquid with OnFroze should transition to Solid and log', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    await machine.transition(OnBirthday());
    expect(machine.isInState<Young>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('State Liquid with OnVaporized should transition to Gas and log', () async {
    final machine = await _createMachine<Alive>(watcher, human);

    expect(machine.isInState<Young>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Invalid transition', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Dead>(watcher, human);
    try {
      await machine.transition(OnBirthday());
      fail('InvalidTransitionException not thrown');
    } catch (e) {
      expect(e, isA<InvalidTransitionException>());
    }
    print('done');
  });

  test('Unreachable State.', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Dead>(watcher, human);
    expect(await machine.analyse(), equals(false));
  });

  test('Transition in nested state.', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Dead>(watcher, human);

    await machine.transition(OnGood());

    /// should be in both states.
    expect(machine.isInState<InHeaven>(), equals(true));
    expect(machine.isInState<Dead>(), equals(true));
  });

  test('calls onExit', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Alive>(watcher, human);
    // await machine.transition(OnBirthday());
    // await machine.transition(OnBirthday());
    //  verify(watcher.onExit(Old));
  });
}

Future<StateMachine> _createMachine<S extends State>(
  Watcher watcher,
  Human human,
) async {
  var machine = StateMachine.create(
    (g) => g
      ..initialState<S>()
      ..state<Alive>((b) => b
        ..on<OnBirthday, Young>(condition: (s, e) => human.age < 18, sideEffect: () => human.age++)
        ..on<OnBirthday, MiddleAged>(condition: (s, e) => human.age < 50, sideEffect: () => human.age++)
        ..on<OnBirthday, Old>(condition: (s, e) => human.age < 80, sideEffect: () => human.age++)
        ..on<OnDeath, Dead>())
      ..state<Young>((b) => b)
      ..state<MiddleAged>((b) => b)
      ..state<Old>((b) => b)
      ..state<Dead>((b) => b
        ..on<OnGood, InHeaven>(condition: (s, e) => s.runtimeType == Dead)
        ..on<OnGood, InHeaven>(condition: (s, e) => s.runtimeType == InHell)
        ..on<OnBad, InHell>(condition: (s, e) => s.runtimeType == InHeaven)
        ..state<InHeaven>((b) => b)
        ..state<InHell>((b) => b))
      ..onTransition((td) => watcher.log('${td.eventType}')),
  );

  return machine;
}

class Human {
  int age = 0;
}

class Alive implements State {}

class Dead implements State {}

class Young extends Alive {}

class MiddleAged implements State {}

class Old implements State {}

class InHeaven implements State {}

class InHell implements State {}

class OnBirthday implements Event {}

class OnDeath implements Event {}

class OnGood implements Event {}

class OnBad implements Event {}
