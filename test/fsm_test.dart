import 'package:dcli/dcli.dart';
import 'package:dcli_core/dcli_core.dart' as core;
import 'package:fsm2/fsm2.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' hide equals;
import 'package:test/test.dart';

import 'watcher.mocks.dart';

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
    await core.withTempDir((tempDir) async {
      final pathTo = join(tempDir, 'fsm_test.smcat');
      await _createMachine<Solid>(watcher)
        ..analyse()
        ..export(pathTo);

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

      final lines =
          read(pathTo).toList().reduce((value, line) => value += '\n$line');

      expect(lines, equals(graph));
    });
  });

  test('initial State should be solid', () async {
    final machine = await _createMachine<Solid>(watcher);

    expect(machine.isInState<Solid>(), equals(true));
  });

  test('State Solid with OnMelted should transition to Liquid and log',
      () async {
    final machine = await _createMachine<Solid>(watcher);

    machine.applyEvent(OnMelted());
    await machine.complete;
    expect(machine.isInState<Liquid>(), equals(true));
    verifyInOrder([watcher.log(onMeltedMessage)]);
  });

  test('State Liquid with OnFroze should transition to Solid and log',
      () async {
    final machine = await _createMachine<Liquid>(watcher)
      ..applyEvent(OnFroze());
    await machine.complete;
    expect(machine.isInState<Solid>(), equals(true));
    verifyInOrder([watcher.log(onFrozenMessage)]);
  });

  test('State Liquid with OnVaporized should transition to Gas and log',
      () async {
    final machine = await _createMachine<Liquid>(watcher);
    machine.applyEvent(OnVaporized());
    await machine.complete;
    expect(machine.isInState<Gas>(), equals(true));
    verifyInOrder([watcher.log(onVaporizedMessage)]);
  });

  test('calls onEnter, but not onExit', () async {
    final watcher = MockWatcher();
    final onMelted = OnMelted();
    final machine = await _createMachine<Solid>(watcher);
    machine.applyEvent(onMelted);
    await machine.complete;
    expect(machine.isInState<Liquid>(), equals(true));
    verify(watcher.onEnter(Liquid, onMelted));
    verifyNever(watcher.onExit(Liquid, onMelted));
  });

  test('calls onExit', () async {
    final watcher = MockWatcher();
    final onMelted = OnMelted();
    final onVaporized = OnVaporized();

    final machine = await _createMachine<Solid>(watcher)
      ..applyEvent(onMelted)
      ..applyEvent(onVaporized);
    await machine.complete;
    verify(watcher.onExit(Liquid, onVaporized));
  });

  test('onEntry for initial state', () async {
    final machine = await _createMachine<Solid>(watcher);
    await machine.complete;
    verify(watcher.onEnter(Solid, machine.initialEvent));
  });
}

Future<StateMachine> _createMachine<S extends State>(
  MockWatcher watcher,
) async =>
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
