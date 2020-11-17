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

  test('initial State should be solid', () {
    final machine = _createMachine<Solid>(watcher);
    expect(machine.isInState<Solid>(), equals(true));
  });

  test('State Solid with OnMelted should transition to Liquid and log', () async {
    final machine = _createMachine<Solid>(watcher);
    await machine.transition(OnMelted());
    expect(machine.isInState<Liquid>(), equals(true));
    verifyInOrder([watcher.log(onMeltedMessage)]);
  });

  test('State Liquid with OnFroze should transition to Solid and log', () async {
    final machine = _createMachine<Liquid>(watcher);
    await machine.transition(OnFroze());
    expect(machine.isInState<Solid>(), equals(true));
    verifyInOrder([watcher.log(onFrozenMessage)]);
  });

  test('State Liquid with OnVaporized should transition to Gas and log', () async {
    final machine = _createMachine<Liquid>(watcher);
    await machine.transition(OnVaporized());
    expect(machine.isInState<Gas>(), equals(true));
    verifyInOrder([watcher.log(onVaporizedMessage)]);
  });

  test('calls onEnter, but not onExit', () async {
    final watcher = Watcher();
    final machine = _createMachine<Solid>(watcher);
    await machine.transition(OnMelted());
    verify(watcher.onEnter(Liquid));
    verifyNever(watcher.onExit(Liquid));
  });

  test('calls onExit', () async {
    final watcher = Watcher();
    final machine = _createMachine<Solid>(watcher);
    await machine.transition(OnMelted());
    await machine.transition(OnVaporized());
    verify(watcher.onExit(Liquid));
  });
}

StateMachine _createMachine<S extends State>(
  Watcher watcher,
) =>
    StateMachine.create((g) => g
          ..initialState<S>()
          ..state<Solid>((b) =>
              b..onDynamic<OnMelted>((s, e) => b.transitionTo<Liquid>(sideEffect: () => watcher.log(onMeltedMessage))))
          ..state<Liquid>((b) => b
            ..onEnter((s, e) => watcher?.onEnter(s.runtimeType))
            ..onExit((s, e) => watcher?.onExit(s.runtimeType))
            ..onDynamic<OnFroze>((s, e) => b.transitionTo<Solid>(sideEffect: () => watcher.log(onFrozenMessage)))
            ..onDynamic<OnVaporized>((s, e) => b.transitionTo<Gas>(sideEffect: () => watcher.log(onVaporizedMessage))))
          ..state<Gas>((b) => b
            ..onDynamic<OnCondensed>(
                (s, e) => b.transitionTo<Liquid>(sideEffect: () => watcher.log(onCondensedMessage))))
        // ..onTransition((t) => onTransition(watcher, t))
        );

const onMeltedMessage = 'onMeltedMessage';
const onFrozenMessage = 'onFrozenMessage';
const onVaporizedMessage = 'onVaporizedMessage';
const onCondensedMessage = 'onCondensedMessage';
