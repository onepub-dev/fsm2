import 'package:dfunc/dfunc.dart';
import 'package:fsm/fsm.dart';
import 'package:test/test.dart';

abstract class State {}

class Solid extends State {}

class Liquid extends State {}

class Gas extends State {}

abstract class Event {}

class OnMelted extends Event {}

class OnFroze extends Event {}

class OnVaporized extends Event {}

class OnCondensed extends Event {}

abstract class SideEffect {}

class LogMelted extends SideEffect {}

class LogFrozen extends SideEffect {}

class LogVaporized extends SideEffect {}

class LogCondensed extends SideEffect {}

class Logger {
  final List<String> messages = [];

  void log(String message) => messages.add(message);
}

void main() {
  Logger logger;

  setUp(() {
    logger = Logger();
  });

  test('initial state should be solid', () {
    final machine = _createMachine(Solid(), logger);
    expect(machine.currentState, isA<Solid>());
  });

  test('state Solid with OnMelted should transition to Liquid and log', () {
    final machine = _createMachine(Solid(), logger);
    machine.transition(OnMelted());
    expect(machine.currentState, isA<Liquid>());
    expect(logger.messages, [onMeltedMessage]);
  });

  test('state Liquid with OnFroze should transition to Solid and log', () {
    final machine = _createMachine(Liquid(), logger);
    machine.transition(OnFroze());
    expect(machine.currentState, isA<Solid>());
    expect(logger.messages, [onFrozenMessage]);
  });

  test('state Liquid with OnVaporized should transition to Gas and log', () {
    final machine = _createMachine(Liquid(), logger);
    machine.transition(OnVaporized());
    expect(machine.currentState, isA<Gas>());
    expect(logger.messages, [onVaporizedMessage]);
  });
}

StateMachine<State, Event, SideEffect> _createMachine(
  State initialState,
  Logger logger,
) =>
    StateMachine<State, Event, SideEffect>.create((g) => g
      ..initialState(initialState)
      ..state<Solid>((b) =>
          b..on<OnMelted>((s, e) => b.transitionTo(Liquid(), LogMelted())))
      ..state<Liquid>((b) => b
        ..on<OnFroze>((s, e) => b.transitionTo(Solid(), LogFrozen()))
        ..on<OnVaporized>((s, e) => b.transitionTo(Gas(), LogVaporized())))
      ..state<Gas>((b) => b
        ..on<OnCondensed>((s, e) => b.transitionTo(Liquid(), LogCondensed())))
      ..onTransition((t) => t.match((v) {
            if (v.sideEffect is LogMelted) logger.log(onMeltedMessage);
            if (v.sideEffect is LogFrozen) logger.log(onFrozenMessage);
            if (v.sideEffect is LogVaporized) logger.log(onVaporizedMessage);
            if (v.sideEffect is LogCondensed) logger.log(onCondensedMessage);
          }, ignore)));

const onMeltedMessage = 'onMeltedMessage';
const onFrozenMessage = 'onFrozenMessage';
const onVaporizedMessage = 'onVaporizedMessage';
const onCondensedMessage = 'onCondensedMessage';
