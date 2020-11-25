import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';

StateMachine machine;
void main() {
  test('export', () async {
    _createMachine();

    await machine.export('test/test.gv');
  }, skip: false);

  test('fork', () async {
    _createMachine();
    expect(machine.isInState<CheckingAir>(), equals(true));
    await machine.applyEvent(OnCheckAir());
    expect(machine.isInState<HandleFan>(), equals(true));
    expect(machine.isInState<HandleLamp>(), equals(true));
    expect(machine.isInState<HandleEquipment>(), equals(true));
    expect(machine.isInState<CleaningAir>(), equals(true));

    var som = machine.stateOfMind;
    var paths = som.activeLeafStates();
    expect(paths.length, equals(2));
    var types =
        som.pathForLeafState(HandleFan).path.map((sd) => sd.stateType).toList();
    expect(
        types, equals([HandleFan, HandleEquipment, CleaningAir, VirtualRoot]));
    types = som
        .pathForLeafState(HandleLamp)
        .path
        .map((sd) => sd.stateType)
        .toList();
    expect(
        types, equals([HandleLamp, HandleEquipment, CleaningAir, VirtualRoot]));

    await machine.export('test/test.gv');
  }, skip: false);
}

void _createMachine() {
  machine = StateMachine.create((g) => g
    ..initialState<CheckingAir>()
    ..state<CheckingAir>((b) => b
      ..onFork<OnCheckAir>((b) => b..target<HandleFan>()..target<HandleLamp>(),
          condition: (s, e) => e.quality < 10))
    ..state<CleaningAir>((b) => b
      ..onExit((s, e) async => turnFanOff())
      ..onExit((s, e) async => turnLightOff())
      ..costate<HandleEquipment>((b) => b
        ..onJoin<WaitForGoodAir>(
            (b) => b..on<OnAirFlowIncreased>()..on<OnLampOn>())
        ..state<HandleFan>((b) => b..onEnter((s, e) async => turnFanOn()))
        ..state<HandleLamp>((b) => b..onEnter((s, e) async => turnLightOn())))
      ..state<WaitForGoodAir>((b) =>
          b..on<OnCheckAir, CheckingAir>(condition: (e) => e.quality > 20))));
}

void turnFanOn() {}

void turnLightOn() {
  machine.applyEvent(OnLampOn());
}

void turnLightOff() {
  machine.applyEvent(OnLampOff());
}

void turnFanOff() {}

class CheckingAir implements State {}

class HandleFan implements State {}

class HandleLamp implements State {}

class HandleEquipment implements State {}

class WaitForGoodAir implements State {}

class CleaningAir implements State {}

class OnCheckAir implements Event {
  int quality;
}

class OnLampOff implements Event {}

class OnAirFlowIncreased implements Event {}

class OnLampOn implements Event {}
