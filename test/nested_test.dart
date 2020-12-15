@Timeout(Duration(minutes: 10))
import 'package:dcli/dcli.dart' hide equals;
import 'package:fsm2/fsm2.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class Watcher extends Mock {
  Future<void> onEnter(Type fromState, Event event);
  Future<void> onExit(Type toState, Event event);

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
    final machine = await _createMachine<Alive>(watcher, human);
    await machine.waitUntilQuiescent;

    expect(machine.isInState<Alive>(), equals(true));
    expect(machine.isInState<Young>(), equals(true));
  });

  test('traverse tree', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    final states = <StateDefinition, StateDefinition>{};
    final transitions = <TransitionDefinition>[];
    await machine.traverseTree((sd, tds) {
      transitions.addAll(tds);
      states[sd] = sd;
    }, includeInherited: false);
    expect(states.length, equals(13));
    expect(transitions.length, equals(7));
    expect(machine.isInState<Alive>(), equals(true));
  });

  test('Test no op transition', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    machine.applyEvent(OnBirthday());
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Alive>(), equals(true));
    expect(machine.isInState<Young>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Test simple transition', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    for (var i = 0; i < 19; i++) {
      machine.applyEvent(OnBirthday());
    }
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Alive>(), equals(true));
    expect(machine.isInState<MiddleAged>(), equals(true));
    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Test multiple transitions', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    machine.applyEvent(OnBirthday());
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Young>(), equals(true));
    machine.applyEvent(OnDeath());
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Dead>(), equals(true));

    verifyInOrder([watcher.log('OnBirthday')]);
  });

  test('Invalid transition', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Dead>(watcher, human);
    try {
      machine.applyEvent(OnBirthday());
      await machine.waitUntilQuiescent;
      fail('InvalidTransitionException not thrown');
    } catch (e) {
      expect(e, isA<InvalidTransitionException>());
    }
  });

  test('Unreachable State.', () async {
    final machine = StateMachine.create(
        (g) => g
          ..initialState<Alive>()
          ..state<Alive>((b) => b..state<Dead>((b) {})),
        production: true);

    expect(machine.analyse(), equals(false));
  });

  test('Transition in nested state.', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Dead>(watcher, human);

    machine.applyEvent(OnJudged(Judgement.good));
    await machine.waitUntilQuiescent;

    /// should be in both states.
    expect(machine.isInState<InHeaven>(), equals(true));
    expect(machine.isInState<Dead>(), equals(true));
  });

  test('calls onExit/onEnter', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Alive>(watcher, human);

    /// age this boy until they are middle aged.
    final onBirthday = OnBirthday();
    for (var i = 0; i < 19; i++) {
      machine.applyEvent(onBirthday);
    }
    await machine.waitUntilQuiescent;
    verify(await watcher.onExit(Young, onBirthday));
    verify(await watcher.onEnter(MiddleAged, onBirthday));
  });

  test('Test onExit/onEnter for nested state change', () async {
    final watcher = Watcher();
    final machine = await _createMachine<Alive>(watcher, human);

    /// age this boy until they are middle aged.
    final onDeath = OnDeath();
    machine.applyEvent(onDeath);
    await machine.waitUntilQuiescent;
    verify(await watcher.onExit(Young, onDeath));
    verify(await watcher.onExit(Alive, onDeath));
    verify(await watcher.onEnter(Dead, onDeath));
    verify(await watcher.onEnter(Purgatory, onDeath));
  });

  test('Export', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    machine.analyse();
    machine.export('test/smcat/nested_test.smcat');

    final lines = read('test/smcat/nested_test.smcat')
        .toList()
        .reduce((value, line) => value += '\n$line');

    expect(lines, equals(_graph));
  });
}

Future<StateMachine> _createMachine<S extends State>(
  Watcher watcher,
  Human human,
) async {
  final machine = StateMachine.create((g) => g
    ..initialState<S>()
    ..state<Alive>((b) => b
      ..initialState<Young>()
      ..onEnter((s, e) async => watcher.onEnter(s, e))
      ..onExit((s, e) async => watcher.onExit(s, e))
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
      ..state<Young>((b) => b..onExit((s, e) async => watcher.onExit(s, e)))
      ..state<MiddleAged>(
          (b) => b..onEnter((s, e) async => watcher.onEnter(s, e)))
      ..state<Old>((b) => b))
    ..state<Dead>((b) => b
      ..onEnter((s, e) async => watcher.onEnter(s, e))

      /// ..initialState<InHeaven>()
      ..state<Purgatory>((b) => b
        ..onEnter((s, e) async => watcher.onEnter(s, e))
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
		Purgatory => Buddhist : OnJudged;
		Purgatory => Catholic : OnJudged;
		Purgatory => SalvationArmy : OnJudged;
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
