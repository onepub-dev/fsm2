import 'package:dcli/dcli.dart' hide equals;
import 'package:fsm2/fsm2.dart';
import 'package:fsm2/src/types.dart';
import 'package:fsm2/src/virtual_root.dart';
import 'package:test/test.dart';

void main() async {
  test('fork', () async {
    var machine = createMachine();
    expect(machine.isInState<MonitorAir>(), equals(true));
    machine.applyEvent(OnBadAir());
    await machine.waitUntilQuiescent;
    expect(machine.isInState<RunFan>(), equals(true));
    expect(machine.isInState<HandleLamp>(), equals(true));
    expect(machine.isInState<CleanAir>(), equals(true));
    expect(machine.isInState<MaintainAir>(), equals(true));

    var som = machine.stateOfMind;
    var paths = som.activeLeafStates();
    expect(paths.length, equals(3));
    var types = som.pathForLeafState(RunFan).path.map((sd) => sd.stateType).toList();
    expect(types, equals([RunFan, CleanAir, MaintainAir, VirtualRoot]));
    types = som.pathForLeafState(HandleLamp).path.map((sd) => sd.stateType).toList();
    expect(types, equals([HandleLamp, CleanAir, MaintainAir, VirtualRoot]));
    types = som.pathForLeafState(WaitForGoodAir).path.map((sd) => sd.stateType).toList();
    expect(types, equals([WaitForGoodAir, CleanAir, MaintainAir, VirtualRoot]));
    print('done1');
    print('done2');
  }, skip: false);

  test('export', () async {
    var machine = createMachine();
    machine.export('test/gv/cleaning_air_test.gv');
    var lines = read('test/gv/cleaning_air_test.gv').toList().reduce((value, line) => value += '\n' + line);

    expect(lines, equals(smcGraph));
  }, skip: false);
}

StateMachine createMachine() {
  StateMachine machine;
  machine = StateMachine.create((g) => g
    ..initialState<MaintainAir>(label: 'TurnOn')
    ..state<MaintainAir>((b) => b
      ..initialState<MonitorAir>()
      ..on<TurnOff, FinalState>()
      ..state<MonitorAir>((b) => b
        ..onFork<OnBadAir>((b) => b..target<RunFan>()..target<HandleLamp>()..target<WaitForGoodAir>(),
            condition: (s, e) => e.quality < 10))
      ..coregion<CleanAir>((b) => b
        ..onExit((s, e) async => turnFanOff())
        ..onExit((s, e) async => await turnLightOff(machine), label: 'TurnLightOn')
        //..onJoin<MonitorAir>((b) => b..on<OnRunning>()..on<OnLampOn>()..on<OnGoodAir>())
        ..state<RunFan>((b) => b
          ..onEnter((s, e) async => turnFanOn())
          ..onJoin<OnRunning, MonitorAir>(condition: ((e) => 2 > 1)))
        // ..onJoin<OnFred, AAAMonitorAir>(condition: ((e) => 2 > 1)))
        ..state<HandleLamp>((b) => b
          ..onEnter((s, e) async => await turnLightOn(machine), label: 'TurnLightOn')
          ..onJoin<OnLampOn, MonitorAir>())
        ..state<WaitForGoodAir>((b) => b..onJoin<OnGoodAir, MonitorAir>()
            // ..on<OnBadAir, WaitForGoodAir>()
            )))
    ..onTransition((s, e, st) {}));

  return machine;
}

var smcGraph = '''

MaintainAir {
	MonitorAir,
	CleanAir.parallel [label="CleanAir"] {
		RunFan,
		HandleLamp,
		WaitForGoodAir;
	};
	MonitorAir.initial => MonitorAir;
	MonitorAir => ]MonitorAir.Fork : OnBadAir;
	]MonitorAir.Fork => RunFan : ;
	]MonitorAir.Fork => HandleLamp : ;
	]MonitorAir.Fork => WaitForGoodAir : ;
	RunFan => ]MonitorAir.Join : OnRunning;
	]MonitorAir.Join => MonitorAir : ;
	HandleLamp => ]MonitorAir.Join : OnLampOn;
	WaitForGoodAir => ]MonitorAir.Join : OnGoodAir;
};
MaintainAir => MaintainAir.final : TurnOff;
initial => MaintainAir : TurnOn;''';

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

Future<void> turnLightOn(StateMachine machine) async {
  machine.applyEvent(OnLampOn());
}

Future<void> turnLightOff(StateMachine machine) async {
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
