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

  test('initial State should be Alive and Young', () async {
    final machine = await _createMachine<Young>(watcher, human);
    expect(machine.isInState<Alive>(), equals(true));
    expect(machine.isInState<Young>(), equals(true));
  });

  test('traverse tree', () async {
    final machine = await _createMachine<Young>(watcher, human);
    var states = <StateDefinition, StateDefinition>{};
    var transitions = <TransitionDefinition>[];
    await machine.traverseTree((sd, tds) {
      transitions.addAll(tds);
      states[sd] = sd;
    }, includeInherited: false);
    expect(states.length, equals(13));
    expect(transitions.length, equals(7));
    expect(machine.isInState<Alive>(), equals(true));
  });

  test('Export', () async {
    final machine = await _createMachine<Young>(watcher, human);
    await machine.analyse();
    await machine.export('test/test.gv'); // .then(expectAsync0<bool>(() {}));
    // expectAsync1<bool, String>((a) => machine.export('/tmp/fsm.txt'));
  });

  test('Test no op transition', () async {
    final machine = await _createMachine<Young>(watcher, human);
    await machine.applyEvent(OnBirthday());
    expect(machine.isInState<Alive>(), equals(true));
    expect(machine.isInState<Young>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Test simple transition', () async {
    final machine = await _createMachine<Young>(watcher, human);
    for (var i = 0; i < 19; i++) {
      await machine.applyEvent(OnBirthday());
    }
    expect(machine.isInState<Alive>(), equals(true));
    expect(machine.isInState<MiddleAged>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Test multiple transitions', () async {
    final machine = await _createMachine<Young>(watcher, human);
    await machine.applyEvent(OnBirthday());
    expect(machine.isInState<Young>(), equals(true));
    await machine.applyEvent(OnDeath());
    expect(machine.isInState<Dead>(), equals(true));

    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Invalid transition', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Purgatory>(watcher, human);
    try {
      await machine.applyEvent(OnBirthday());
      fail('InvalidTransitionException not thrown');
    } catch (e) {
      expect(e, isA<InvalidTransitionException>());
    }
  });

  test('Unreachable State.', () async {
    var machine = StateMachine.create(
        (g) => g
          ..initialState<Alive>()
          ..state<Alive>((b) => b..state<Dead>((b) {})),
        production: true);

    expect(await machine.analyse(), equals(false));
  });

  test('Transition in nested state.', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Purgatory>(watcher, human);

    await machine.applyEvent(OnJudged(Judgement.good));

    /// should be in both states.
    expect(machine.isInState<InHeaven>(), equals(true));
    expect(machine.isInState<Dead>(), equals(true));
  });

  test('calls onExit', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Young>(watcher, human);
    await machine.applyEvent(OnBirthday());
    // verify(watcher.onExit((s,e ) {} )));
  });
}

Future<StateMachine> _createMachine<S extends State>(
  Watcher watcher,
  Human human,
) async {
  var machine = StateMachine.create((g) => g
    ..initialState<S>()
    ..state<Alive>((b) => b
      ..initialState<Young>()
      ..onEnter((s, e) async => print('onEnter $s as a result of $e'))
      ..onExit((s, e) async => print('onExit $s as a result of $e'))
      ..on<OnBirthday, Young>(
          condition: (e) => human.age < 18, sideEffect: () async => human.age++)
      ..on<OnBirthday, MiddleAged>(
          condition: (e) => human.age < 50, sideEffect: () async => human.age++)
      ..on<OnBirthday, Old>(
          condition: (e) => human.age < 80, sideEffect: () async => human.age++)
      ..on<OnDeath, Purgatory>()
      ..state<Young>((b) => b)
      ..state<MiddleAged>((b) => b)
      ..state<Old>((b) => b))
    ..state<Dead>((b) => b

      /// ..initialState<InHeaven>()
      ..state<Purgatory>((b) => b
        ..on<OnJudged, Buddhist>(
            condition: (e) => e.judgement == Judgement.good)
        ..on<OnJudged, Catholic>(condition: (e) => e.judgement == Judgement.bad)
        ..on<OnJudged, SalvationArmy>(
            condition: (e) => e.judgement == Judgement.ugly))
      ..state<InHeaven>((b) => b..state<Buddhist>((b) => b))
      ..state<InHell>((b) => b
        ..state<Christian>(
            (b) => b..state<SalvationArmy>((b) {})..state<Catholic>((b) => b))))
    ..onTransition((from, event, to) => watcher.log('${event.runtimeType}')));
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

class Purgatory implements State {}

class InHeaven implements State {}

class InHell implements State {}

class Christian implements State {}

class Buddhist implements State {}

class Catholic implements State {}

class SalvationArmy implements State {}

/// events

class OnBirthday implements Event {}

class OnDeath implements Event {}

enum Judgement { good, bad, ugly }

class OnJudged implements Event {
  Judgement judgement;

  OnJudged(this.judgement);
}
