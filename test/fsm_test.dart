import 'package:dcli/dcli.dart' hide equals;
import 'package:fsm2/fsm2.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class Solid implements State {}

class Liquid implements State {}

class Gas implements State {}

class OnMelted implements Event {}

class OnFroze implements Event {}

class OnVaporized implements Event {}

class OnCondensed implements Event {}

class Watcher extends Mock {
  void onEnter(Type t);

  void onExit(Type t);

  void log(String message);
}

void main() {
  Watcher watcher;

  setUp(() {
    watcher = Watcher();
  });

  test('export', () async {
    final machine = _createMachine<Solid>(watcher);
    machine.analyse();
    machine.export('test/smcat/fsm_test.smcat');

    var graph = '''

Solid {
	Solid => Liquid : OnMelted;
},
Liquid {
	Liquid => Solid : OnFroze;
	Liquid => Gas : OnVaporized;
},
Gas {
	Gas => Liquid : OnCondensed;
};
initial => Solid : Solid;''';

    var lines = read('test/smcat/fsm_test.smcat').toList().reduce((value, line) => value += '\n' + line);

    expect(lines, equals(graph));
  });

  test('initial State should be solid', () {
      final machine = _createMachine<Solid>(watcher);
      
      expect(machine.isInState<Solid>(), equals(true));
  });

  test('State Solid with OnMelted should transition to Liquid and log', () async {
      final machine = _createMachine<Solid>(watcher);
      machine.applyEvent(OnMelted());
      await machine.waitUntilQuiescent;
      expect(machine.isInState<Liquid>(), equals(true));
      verifyInOrder([watcher.log(onMeltedMessage)]);
  });

  test('State Liquid with OnFroze should transition to Solid and log', () async {
      final machine = _createMachine<Liquid>(watcher);
      machine.applyEvent(OnFroze());
      await machine.waitUntilQuiescent;
      expect(machine.isInState<Solid>(), equals(true));
      verifyInOrder([watcher.log(onFrozenMessage)]);
  });

  test('State Liquid with OnVaporized should transition to Gas and log', () async {
    final machine = _createMachine<Liquid>(watcher);
      machine.applyEvent(OnVaporized());
      await machine.waitUntilQuiescent;
      expect(machine.isInState<Gas>(), equals(true));
      verifyInOrder([watcher.log(onVaporizedMessage)]);
  });

  test('calls onEnter, but not onExit', () async {
      final watcher = Watcher();
      final machine = _createMachine<Solid>(watcher);
      machine.applyEvent(OnMelted());
      await machine.waitUntilQuiescent;
      expect(machine.isInState<Liquid>(), equals(true));
      verify(watcher.onEnter(Liquid));
      verifyNever(watcher.onExit(Liquid));
  });

  test('calls onExit', () async {
      final watcher = Watcher();
      final machine = _createMachine<Solid>(watcher);
      machine.applyEvent(OnMelted());
      machine.applyEvent(OnVaporized());
      await machine.waitUntilQuiescent;
      verify(watcher.onExit(Liquid));
  });
}

StateMachine _createMachine<S extends State>(
  Watcher watcher,
) =>
    StateMachine.create(
        (g) => g
          ..initialState<S>()
          ..state<Solid>((b) => b
            ..on<OnMelted, Liquid>(sideEffect: () async => watcher.log(onMeltedMessage))
            ..onEnter((s, e) async => watcher?.onEnter(s))
            ..onExit((s, e) async => watcher?.onExit(s)))
          ..state<Liquid>((b) => b
            ..onEnter((s, e) async => watcher?.onEnter(s))
            ..onExit((s, e) async => watcher?.onExit(s))
            ..on<OnFroze, Solid>(sideEffect: () async => watcher.log(onFrozenMessage))
            ..on<OnVaporized, Gas>(sideEffect: () async => watcher.log(onVaporizedMessage)))
          ..state<Gas>((b) => b..on<OnCondensed, Liquid>(sideEffect: () async => watcher.log(onCondensedMessage)))
          ..onTransition((from, event, to) => print('${from} ${event} ${to} ')),
        production: true);

const onMeltedMessage = 'onMeltedMessage';
const onFrozenMessage = 'onFrozenMessage';
const onVaporizedMessage = 'onVaporizedMessage';
const onCondensedMessage = 'onCondensedMessage';
