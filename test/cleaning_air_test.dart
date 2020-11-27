import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';

StateMachine machine;
void main() {
  test('fork', () async {
    _createMachine();
    expect(machine.isInState<MonitorAir>(), equals(true));
    await machine.applyEvent(OnBadAir());
    expect(machine.isInState<RunFan>(), equals(true));
    expect(machine.isInState<HandleLamp>(), equals(true));
    expect(machine.isInState<HandleEquipment>(), equals(true));
    expect(machine.isInState<MaintainAir>(), equals(true));

    var som = machine.stateOfMind;
    var paths = som.activeLeafStates();
    expect(paths.length, equals(2));
    var types = som.pathForLeafState(RunFan).path.map((sd) => sd.stateType).toList();
    expect(types, equals([RunFan, HandleEquipment, MaintainAir, VirtualRoot]));
    types = som.pathForLeafState(HandleLamp).path.map((sd) => sd.stateType).toList();
    expect(types, equals([HandleLamp, HandleEquipment, MaintainAir, VirtualRoot]));
  }, skip: false);

  test('export', () async {
    _createMachine();

    await machine.export('test/gv/cleaning_air_test.gv');
  }, skip: false);
}

void _createMachine() {
  machine = StateMachine.create((g) => g
    ..initialState<MonitorAir>()
    ..state<MaintainAir>((b) => b
      ..on<OnBadAir, RunFan>()
      ..state<MonitorAir>((b) => b
        ..onFork<OnBadAir>((b) => b..target<RunFan>()..target<HandleLamp>()..target<WaitForGoodAir>(),
            condition: (s, e) => e.quality < 10))
      ..state<CleanAir>((b) => b
        ..onExit((s, e) async => turnFanOff())
        ..onExit((s, e) async => turnLightOff())
        ..costate<HandleEquipment>((b) => b
          ..onJoin<WaitForGoodAir>((b) => b..on<OnAirFlowIncreased>()..on<OnLampOn>()..on<OnGoodAir>())
          ..state<RunFan>((b) => b..onEnter((s, e) async => turnFanOn()))
          ..state<HandleLamp>((b) => b..onEnter((s, e) async => turnLightOn()))
          ..state<WaitForGoodAir>((b) {})))));
}

var graph = '''stateDiagram-v2
    [*] --> MaintainAir
    state MaintainAir {
        [*] --> MonitorAir 
        
        CleanAir --> MonitorAir : onGoodAir 
        MonitorAir  --> CleanAir : OnBadAir

        state CleanAir {
        [*] --> HandleEquipment
        HandleEquipment --> [*]
        state HandleEquipment {
            HandleLamp
            HandleFan 
            WaitForGoodAir

            state BBB <<fork>> 
              [*] --> BBB 
              BBB --> HandleLamp
              BBB --> HandleFan
              BBB --> WaitForGoodAir

            state AAA <<join>>
              HandleLamp --> AAA
              HandleFan --> AAA
              WaitForGoodAir --> AAA
              AAA --> [*] 
        }
        }
    }
    ''';

void turnFanOn() {}

void turnLightOn() {
  machine.applyEvent(OnLampOn());
}

void turnLightOff() {
  machine.applyEvent(OnLampOff());
}

void turnFanOff() {}

class MonitorAir implements State {}

class CleanAir implements State {}

class RunFan implements State {}

class HandleLamp implements State {}

class HandleEquipment implements State {}

class WaitForGoodAir implements State {}

class MaintainAir implements State {}

class OnBadAir implements Event {
  int quality;
}

class OnLampOff implements Event {}

class OnAirFlowIncreased implements Event {}

class OnLampOn implements Event {}

class OnGoodAir implements Event {}
