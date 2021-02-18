import 'package:dcli/dcli.dart' hide equals;
import 'package:fsm2/fsm2.dart';
import 'package:fsm2/src/types.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'mock_watcher.dart';

class Solid implements State {}

class Liquid implements State {}

class Gas implements State {}

class OnMelted implements Event {}

class OnFroze implements Event {}

class OnVaporized implements Event {}

class OnCondensed implements Event {}

void main() {
  late MockWatcher watcher;

  setUp(() {
    watcher = MockWatcher();
  });

  test('export', () async {
    final machine = _createMachine<Solid>(watcher);
    machine.analyse();
    machine.export('test/smcat/fsm_test.smcat');

    const graph = '''

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

    final lines = read('test/smcat/fsm_test.smcat')
        .toList()
        .reduce((value, line) => value += '\n$line');

    expect(lines, equals(graph));
  });

  test('initial State should be solid', () {
    final machine = _createMachine<Solid>(watcher);

    expect(machine.isInState<Solid>(), equals(true));
  });

  test('State Solid with OnMelted should transition to Liquid and log',
      () async {
    final machine = _createMachine<Solid>(watcher);
    machine.applyEvent(OnMelted());
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Liquid>(), equals(true));
    verifyInOrder([watcher.log(onMeltedMessage)]);
  });

  test('State Liquid with OnFroze should transition to Solid and log',
      () async {
    final machine = _createMachine<Liquid>(watcher);
    machine.applyEvent(OnFroze());
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Solid>(), equals(true));
    verifyInOrder([watcher.log(onFrozenMessage)]);
  });

  test('State Liquid with OnVaporized should transition to Gas and log',
      () async {
    final machine = _createMachine<Liquid>(watcher);
    machine.applyEvent(OnVaporized());
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Gas>(), equals(true));
    verifyInOrder([watcher.log(onVaporizedMessage)]);
  });

  test('calls onEnter, but not onExit', () async {
    final watcher = MockWatcher();
    final onMelted = OnMelted();
    final machine = _createMachine<Solid>(watcher);
    machine.applyEvent(onMelted);
    await machine.waitUntilQuiescent;
    expect(machine.isInState<Liquid>(), equals(true));
    verify(watcher.onEnter(Liquid, onMelted));
    verifyNever(watcher.onExit(Liquid, onMelted));
  });

  test('calls onExit', () async {
    final watcher = MockWatcher();
    final onMelted = OnMelted();
    final onVaporized = OnVaporized();

    final machine = _createMachine<Solid>(watcher);
    machine.applyEvent(onMelted);
    machine.applyEvent(onVaporized);
    await machine.waitUntilQuiescent;
    verify(watcher.onExit(Liquid, onVaporized));
  });

  test('onEntry for initial state', () async {
    final machine = _createMachine<Solid>(watcher);
    await machine.waitUntilQuiescent;
    verify(watcher.onEnter(Solid, machine.initialEvent));
  });
}

StateMachine _createMachine<S extends State>(
  MockWatcher watcher,
) =>
    StateMachine.create(
        (g) => g
          ..initialState<S>()
          ..state<Solid>((b) => b
            ..on<OnMelted, Liquid>(
                sideEffect: (e) async => watcher.log(onMeltedMessage))
            ..onEnter((s, e) async => watcher.onEnter(s, e))
            ..onExit((s, e) async => watcher.onExit(s, e)))
          ..state<Liquid>((b) => b
            ..onEnter((s, e) async => watcher.onEnter(s, e))
            ..onExit((s, e) async => watcher.onExit(s, e))
            ..on<OnFroze, Solid>(
                sideEffect: (e) async => watcher.log(onFrozenMessage))
            ..on<OnVaporized, Gas>(
                sideEffect: (e) async => watcher.log(onVaporizedMessage)))
          ..state<Gas>((b) => b
            ..on<OnCondensed, Liquid>(
                sideEffect: (e) async => watcher.log(onCondensedMessage)))
          // ignore: avoid_print
          ..onTransition((from, event, to) => print('$from $event $to ')),
        production: true);

const onMeltedMessage = 'onMeltedMessage';
const onFrozenMessage = 'onFrozenMessage';
const onVaporizedMessage = 'onVaporizedMessage';
const onCondensedMessage = 'onCondensedMessage';
