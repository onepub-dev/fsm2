import 'package:fsm2/fsm2.dart';
import 'package:fsm2/src/types.dart';
import 'package:fsm2/src/virtual_root.dart';
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
    var types =
        som.pathForLeafState(RunFan).path.map((sd) => sd.stateType).toList();
    expect(types, equals([RunFan, HandleEquipment, MaintainAir, VirtualRoot]));
    types = som
        .pathForLeafState(HandleLamp)
        .path
        .map((sd) => sd.stateType)
        .toList();
    expect(
        types, equals([HandleLamp, HandleEquipment, MaintainAir, VirtualRoot]));
  }, skip: false);

  test('export', () async {
    _createMachine();

    await machine.export('test/gv/cleaning_air_test.gv');
  }, skip: false);
}

void _createMachine() {
  machine = StateMachine.create((g) => g
    ..initialState<MaintainAir>(label: 'TurnOn')
    ..state<MaintainAir>((b) => b
      ..initialState<MonitorAir>()
      ..on<TurnOff, FinalState>()
      ..state<MonitorAir>((b) => b
//        ..on<OnBadAir, CleanAir>()
        ..onFork<OnBadAir>(
            (b) => b
              ..target<RunFan>()
              ..target<HandleLamp>()
              ..target<WaitForGoodAir>(),
            condition: (s, e) => e.quality < 10))
      ..coregion<CleanAir>((b) => b
        ..onExit((s, e) async => turnFanOff())
        ..onExit((s, e) async => turnLightOff(), label: 'TurnLightOn')
        //..onJoin<MonitorAir>((b) => b..on<OnRunning>()..on<OnLampOn>()..on<OnGoodAir>())
        ..state<RunFan>((b) => b
          ..onEnter((s, e) async => turnFanOn())
          ..onJoin<OnRunning, MonitorAir>(condition: ((e) => 2 > 1)))
        // ..onJoin<OnFred, AAAMonitorAir>(condition: ((e) => 2 > 1)))
        ..state<HandleLamp>((b) => b
          ..onEnter((s, e) async => turnLightOn(), label: 'TurnLightOn')
          ..onJoin<OnLampOn, MonitorAir>())
        ..state<WaitForGoodAir>((b) => b..onJoin<OnGoodAir, MonitorAir>()
            // ..on<OnBadAir, WaitForGoodAir>()
            ))));
}

var smcGraph = '''initial,
MaintainAir
{
  MonitorAir {
    MonitorAir => CleanAir.parallel : OnBadAir;
  },

	CleanAir.parallel [label="CleanAir"]
	{
    ]CleanAir.Fork1,
		RunFan,
		HandleLamp,
		WaitForGoodAir;
    initial.cleanair => ]CleanAir.Fork1;
    WaitForGoodAir => WaitForGoodAir : OnBadAir;
 
    ]CleanAir.Fork1=> RunFan;
    ]CleanAir.Fork1=> HandleLamp;
    ]CleanAir.Fork1=> WaitForGoodAir;

    RunFan => ]HandleEquipmentJoin1 : OnRunning;
    HandleLamp => ]HandleEquipmentJoin1: OnLampOn;
    WaitForGoodAir => ]HandleEquipmentJoin1 : GoodAir;
    ]HandleEquipmentJoin1=> cleanair.final ;

    CleanAir.parallel  => MonitorAir : GoodAir;

	};
  initial.MonitorAir => MonitorAir ;
  MonitorAir => final.MaintainAir ;
};

initial => MaintainAir : TurnOn;
MaintainAir => final : TurnOff;
''';

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

class OnRunning implements Event {}

class OnLampOn implements Event {}

class OnGoodAir implements Event {}

class TurnOff implements Event {}
