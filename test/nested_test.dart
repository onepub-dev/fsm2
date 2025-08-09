@Timeout(Duration(minutes: 10))
library;

import 'package:dcli/dcli.dart';
import 'package:dcli_core/dcli_core.dart' as core;
import 'package:fsm2/fsm2.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' hide equals;
import 'package:test/test.dart';

import 'watcher.mocks.dart';

void main() {
  late MockWatcher watcher;
  late Human human;

  setUp(() {
    watcher = MockWatcher();
    human = Human();
  });

  test('initial State should be Alive and Young', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    await machine.complete;

    expect(await machine.isInState<Alive>(), equals(true));
    expect(await machine.isInState<Young>(), equals(true));
  });

  test('traverse tree', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    final states = <StateDefinition, StateDefinition>{};
    final transitions = <TransitionDefinition>[];
    await machine.traverseTree((sd, tds) {
      transitions.addAll(tds);
      states[sd] = sd;
    }, includeInherited: false);
    expect(states.length, equals(14));
    expect(transitions.length, equals(8));
    expect(await machine.isInState<Alive>(), equals(true));
  });

  test('Test no op transition', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    machine.applyEvent(OnBirthday());
    await machine.complete;
    expect(await machine.isInState<Alive>(), equals(true));
    expect(await machine.isInState<Young>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Test simple transition', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    for (var i = 0; i < 19; i++) {
      machine.applyEvent(OnBirthday());
    }
    await machine.complete;
    expect(await machine.isInState<Alive>(), equals(true));
    expect(await machine.isInState<MiddleAged>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Test multiple transitions', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    machine.applyEvent(OnBirthday());
    await machine.complete;
    expect(await machine.isInState<Young>(), equals(true));
    machine.applyEvent(OnDeath());
    await machine.complete;
    expect(await machine.isInState<Dead>(), equals(true));

    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Invalid transition', () async {
    final watcher = MockWatcher();
    final machine = await _createMachine<Dead>(watcher, human);
    try {
      machine.applyEvent(OnBirthday());
      await machine.complete;
      fail('InvalidTransitionException not thrown');
      // handled in the expect.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      expect(e, isA<InvalidTransitionException>());
    }
  });

  test('Transition to child state', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    machine.applyEvent(OnDeath());
    await machine.complete;
    expect(await machine.isInState<Purgatory>(), equals(true));
    machine.applyEvent(OnJudged(Judgement.morallyAmbiguous));
    await machine.complete;
    expect(await machine.isInState<Matrix>(), equals(true));
    expect(await machine.isInState<Dead>(), equals(true));
    expect(await machine.isInState<Purgatory>(), equals(true));

    /// We should be MiddleAged but Alive should not be a separate path.
    expect(machine.stateOfMind.activeLeafStates().length, 1);
  });

  test('Unreachable State.', () async {
    final machine = await StateMachine.create(
        (g) => g
          ..initialState<Alive>()
          ..state<Alive>((b) => b..state<Dead>((b) {})),
        production: true);

    expect(machine.analyse(), equals(false));
  });

  test('Transition in nested state.', () async {
    final watcher = MockWatcher();
    final machine = await _createMachine<Dead>(watcher, human);

    machine.applyEvent(OnJudged(Judgement.good));
    await machine.complete;

    /// should be in both states.
    expect(await machine.isInState<InHeaven>(), equals(true));
    expect(await machine.isInState<Dead>(), equals(true));
  });

  test('calls onExit/onEnter', () async {
    final watcher = MockWatcher();
    final machine = await _createMachine<Alive>(watcher, human);

    /// age this boy until they are middle aged.
    final onBirthday = OnBirthday();
    for (var i = 0; i < 19; i++) {
      machine.applyEvent(onBirthday);
    }
    await machine.complete;
    verify(await watcher.onExit(Young, onBirthday));
    verify(await watcher.onEnter(MiddleAged, onBirthday));
  });

  test('Test onExit/onEnter for nested state change', () async {
    final watcher = MockWatcher();
    final machine = await _createMachine<Alive>(watcher, human);

    /// age this boy until they are middle aged.
    final onDeath = OnDeath();
    machine.applyEvent(onDeath);
    await machine.complete;
    verify(await watcher.onExit(Young, onDeath));
    verify(await watcher.onExit(Alive, onDeath));
    verify(await watcher.onEnter(Dead, onDeath));
    verify(await watcher.onEnter(Purgatory, onDeath));
  });

  test('Export', () async {
    await core.withTempDirAsync((tempDir) async {
      final pathToSmCat = join(tempDir, 'nested_test.smcat');
      final machine = await _createMachine<Alive>(watcher, human);
      machine
        ..analyse()
        ..export(pathToSmCat);

      final lines = read(pathToSmCat)
          .toList()
          .reduce((value, line) => value += '\n$line');

      expect(lines, equals(_graph));
    });
  });
}

Future<StateMachine> _createMachine<S extends State>(
  MockWatcher watcher,
  Human human,
) {
  final machine = StateMachine.create((g) => g
    ..initialState<S>()
    ..state<Alive>((b) => b
      ..initialState<Young>()
      ..onEnter((s, e) => watcher.onEnter(s, e))
      ..onExit((s, e) => watcher.onExit(s, e))
      ..on<OnBirthday, Young>(
          condition: (e) => human.age < 18,
          sideEffect: (e) async => human.age++)
      ..on<OnBirthday, MiddleAged>(
          condition: (e) => human.age < 50,
          sideEffect: (e) async => human.age++)
      ..on<OnBirthday, Old>(
          condition: (e) => human.age < 80,
          sideEffect: (e) async => human.age++)
      ..on<OnDeath, Purgatory>()
      ..state<Young>((b) => b..onExit((s, e) => watcher.onExit(s, e)))
      ..state<MiddleAged>((b) => b..onEnter((s, e) => watcher.onEnter(s, e)))
      ..state<Old>((b) => b))
    ..state<Dead>((b) => b
      ..onEnter((s, e) => watcher.onEnter(s, e))

      /// ..initialState<InHeaven>()
      ..state<Purgatory>((b) => b
        ..onEnter((s, e) => watcher.onEnter(s, e))
        ..on<OnJudged, Buddhist>(
            condition: (e) => e.judgement == Judgement.good)
        ..on<OnJudged, Catholic>(condition: (e) => e.judgement == Judgement.bad)
        ..on<OnJudged, SalvationArmy>(
            condition: (e) => e.judgement == Judgement.ugly)
        ..on<OnJudged, Matrix>(
            condition: (e) => e.judgement == Judgement.morallyAmbiguous)
        ..state<Matrix>((_) {}))
      ..state<InHeaven>((b) => b..state<Buddhist>((b) => b))
      ..state<InHell>((b) => b
        ..state<Christian>((b) => b
          ..state<SalvationArmy>((b) {})
          ..state<Catholic>((b) => b))))
    ..onTransition((from, event, to) => watcher.log('${event.runtimeType}')));
  return machine;
}

class Human {
  // not part of our public api
  // ignore: type_annotate_public_apis
  var age = 0;
}

class Alive extends State {}

class Dead extends State {}

class Young extends Alive {}

class MiddleAged extends State {}

class Old extends State {}

class Purgatory extends State {}

class Matrix extends State {}

class InHeaven extends State {}

class InHell extends State {}

class Christian extends State {}

class Buddhist extends State {}

class Catholic extends State {}

class SalvationArmy extends State {}

/// events

class OnBirthday extends Event {}

class OnDeath extends Event {}

enum Judgement { good, bad, ugly, morallyAmbiguous }

class OnJudged implements Event {
  Judgement judgement;

  OnJudged(this.judgement);
}

var _graph = '''

Alive {
	Young,
	MiddleAged,
	Old;
	Young.initial => Young;
	Alive => Young : OnBirthday;
	Alive => MiddleAged : OnBirthday;
	Alive => Old : OnBirthday;
	Alive => Purgatory : OnDeath;
},
Dead {
	Purgatory {
		Matrix;
		Matrix.initial => Matrix;
		Purgatory => Buddhist : OnJudged;
		Purgatory => Catholic : OnJudged;
		Purgatory => SalvationArmy : OnJudged;
		Purgatory => Matrix : OnJudged;
	},
	InHeaven {
		Buddhist;
		Buddhist.initial => Buddhist;
	},
	InHell {
		Christian {
			SalvationArmy,
			Catholic;
			SalvationArmy.initial => SalvationArmy;
		};
		Christian.initial => Christian;
	};
	Purgatory.initial => Purgatory;
};
initial => Alive : Alive;''';
