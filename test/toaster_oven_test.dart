import 'package:dcli_core/dcli_core.dart' as core;
import 'package:fsm2/fsm2.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  test('export', () async {
    await core.withTempDirAsync((tempDir) async {
      await _createMachine()
        ..analyse()
        ..export(join(tempDir, 'toaster_oven.smcat'));
    });
  }, skip: false);
}

Future<StateMachine> _createMachine() async => StateMachine.create((g) => g
  ..initialState<DoorClosed>()
  ..state<DoorClosed>((b) => b
    ..on<OnBake, Baking>()
    ..on<OnToast, Toasting>())
  ..state<DoorOpen>((b) => b..on<OnCloseDoor, DoorClosed>())
  ..state<Heating>((b) => b
    ..on<OnOpenDoor, DoorOpen>()
    ..state<Toasting>((b) {})
    ..state<Baking>((b) {})));

class DoorOpen implements State {}

class DoorClosed implements State {}

class Toasting implements State {}

class Baking implements State {}

class Heating implements State {}

// class LightOn implements State {}

class OnOpenDoor implements Event {}

class OnCloseDoor implements Event {}

// class OnTurnOff implements Event {}

class OnToast implements Event {}

class OnBake implements Event {}
