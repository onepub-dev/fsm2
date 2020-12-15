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

  test('Export', () async {
    final machine = await _createMachine<Alive>(watcher, human);
    machine.analyse();
    // ignore: unused_local_variable
    final pages = machine.export('test/smcat/page_break_test.smcat');

    // var pageNo = 0;
    // for (final page in pages.pages) {
    //   final lines =
    //       read(page.path).toList().reduce((value, line) => value += '\n$line');
    //   expect(lines, equals(_graphs[pageNo++]));
    // }
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
          condition: (e) => human.age < 18, sideEffect: (e) async => human.age++)
      ..on<OnBirthday, MiddleAged>(
          condition: (e) => human.age < 50, sideEffect: (e) async => human.age++)
      ..on<OnBirthday, Old>(
          condition: (e) => human.age < 80, sideEffect: (e) async => human.age++)
      ..on<OnDeath, Purgatory>()
      ..state<Young>((b) => b..onExit((s, e) async => watcher.onExit(s, e)))
      ..state<MiddleAged>(
          (b) => b..onEnter((s, e) async => watcher.onEnter(s, e)))
      ..state<Old>((b) => b))
    ..state<Dead>((b) => b
      ..pageBreak
      ..onEnter((s, e) async => watcher.onEnter(s, e))

      /// ..initialState<InHeaven>()
      ..state<Purgatory>((b) => b
        ..pageBreak
        ..onEnter((s, e) async => watcher.onEnter(s, e))
        ..on<OnJudged, Buddhist>(
            condition: (e) => e.judgement == Judgement.good,
            conditionLabel: 'good')
        ..on<OnJudged, Catholic>(
            condition: (e) => e.judgement == Judgement.bad,
            conditionLabel: 'bad')
        ..on<OnJudged, SalvationArmy>(
            condition: (e) => e.judgement == Judgement.ugly,
            conditionLabel: 'ugly'))
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

// ignore: unused_element
var _graphs = <String>[
  '''

Alive {
	Young,
	MiddleAged,
	Old;
	Young.initial => Young;
	Alive => Young : OnBirthday;
	Alive => MiddleAged : OnBirthday;
	Alive => Old : OnBirthday;
},
Dead[color="blue"];
Alive => Dead : OnDeath;
initial => Alive : Alive;''',
  '''

Dead {
Purgatory {
	Purgatory => Buddhist : OnJudged [good];
	Purgatory => Catholic : OnJudged [bad];
	Purgatory => SalvationArmy : OnJudged [ugly];
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
]Purgatory.initial => Purgatory : OnDeath;
};'''
];
