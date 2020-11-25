import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';

void main() {
  test('export', () async {
    final machine = _createMachine();
    await machine.analyse();
    await machine.export('test/test.gv');
  }, skip: false);
}

StateMachine _createMachine() {
  return StateMachine.create((g) => g
    ..initialState<DoorClosed>()
    ..state<DoorClosed>((b) => b..on<OnBake, Baking>()..on<OnToast, Toasting>())
    ..state<DoorOpen>((b) {})
    ..state<Heating>((b) => b
      ..on<OpenDoor, DoorOpen>()
      ..state<Toasting>((b) {})
      ..state<Baking>((b) {})));

  // ..state<LightOff>((b) => b..on<OnTurnOn, LightOn>())
  // ..state<LightOn>((b) => b..on<OnTurnOff, LightOff>()));
}

class DoorOpen implements State {}

class DoorClosed implements State {}

class Toasting implements State {}

class Baking implements State {}

class Heating implements State {}

class LightOn implements State {}

class OpenDoor implements Event {}

class OnTurnOff implements Event {}

class OnToast implements Event {}

class OnBake implements Event {}
