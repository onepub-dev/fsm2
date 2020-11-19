import 'package:fsm2/fsm2.dart';
import 'package:fsm2/src/state_definition.dart';
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

  test('traverse tree', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    var states = <StateDefinition, StateDefinition>{};
    var transitions = <TransitionDefinition>[];
    await machine.traverseTree((sd, td) {
      transitions.add(td);
      states[sd] = sd;
    });
    expect(states.length, equals(7));
    expect(transitions.length, equals(12));
    expect(machine.isInState<Alive>(), equals(true));
  });

  test('Export', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    await machine.analyse();
    await machine.export('test/test.gv'); // .then(expectAsync0<bool>(() {}));
    // expectAsync1<bool, String>((a) => machine.export('/tmp/fsm.txt'));
  });

  test('Test simple transition', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    await machine.transition(OnBirthday());
    expect(machine.isInState<Young>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Test multiple transitions', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    await machine.transition(OnBirthday());
    expect(machine.isInState<Young>(), equals(true));
    await machine.transition(OnDeath());
    expect(machine.isInState<Dead>(), equals(true));

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
    await machine.transition(OnBirthday());
    // verify(watcher.onExit((s,e ) => )));
  });
}

Future<StateMachine> _createMachine<S extends State>(
  Watcher watcher,
  Human human,
) async {
  var machine = StateMachine.create((g) => g
    ..initialState<S>()
    ..state<Alive>((b) => b
      ..onEnter((s, e) => print('onEnter $s as a result of $e'))
      ..onExit((s, e) => print('onExit $s as a result of $e'))
      ..on<OnBirthday, Young>(condition: (s, e) => human.age < 18, sideEffect: () => human.age++)
      ..on<OnBirthday, MiddleAged>(condition: (s, e) => human.age < 50, sideEffect: () => human.age++)
      ..on<OnBirthday, Old>(condition: (s, e) => human.age < 80, sideEffect: () => human.age++)
      ..on<OnDeath, Dead>()
      ..state<Young>((b) => b)
      ..state<MiddleAged>((b) => b)
      ..state<Old>((b) => b))
    ..state<Dead>((b) => b
      ..on<OnGood, Buddhist>(condition: (s, e) => s == Dead)
      ..on<OnUgly, SalvationArmy>(condition: (s, e) => s == InHell)
      ..on<OnBad, Christian>(condition: (s, e) => s == InHeaven)
      ..state<InHeaven>((b) => b..state<Buddhist>((b) => b))
      ..state<InHell>((b) => b..state<Christian>((b) => b..state<Catholic>((b) => b)..state<SalvationArmy>((b) => b))))
    ..onTransition((td) => watcher.log('${td.eventType}')));

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

class Christian implements State {}

class Buddhist implements State {}

class Catholic implements State {}

class SalvationArmy implements State {}

/// events

class OnBirthday implements Event {}

class OnDeath implements Event {}

class OnGood implements Event {}

class OnUgly implements Event {}

class OnBad implements Event {}
