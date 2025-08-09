@Timeout(Duration(minutes: 30))
library;

import 'dart:developer';

import 'package:dcli/dcli.dart';
import 'package:dcli_core/dcli_core.dart' as core;
import 'package:fsm2/fsm2.dart';
import 'package:fsm2/src/virtual_root.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' hide equals;
import 'package:test/test.dart';

import 'watcher.mocks.dart';

final onBadAir = OnBadAir(8);

final onGoodAir = OnGoodAir();

final onFanRunning = OnFanRunning();
final onLampOn = OnLampOn();

void main() {
  test('fork', () async {
    final watcher = MockWatcher();
    final machine = await createMachine(watcher);
    expect(await machine.isInState<MonitorAir>(), equals(true));
    machine.applyEvent(onBadAir);
    await machine.complete;
    expect(await machine.isInState<HandleFan>(), equals(true));
    expect(await machine.isInState<HandleLamp>(), equals(true));
    expect(await machine.isInState<CleanAir>(), equals(true));
    expect(await machine.isInState<MaintainAir>(), equals(true));

    final som = machine.stateOfMind;
    final paths = som.activeLeafStates();
    expect(paths.length, equals(3));
    var types = som
        .pathForLeafState(HandleFan)!
        .path
        .map((sd) => sd.stateType)
        .toList();
    expect(types, equals([HandleFan, CleanAir, MaintainAir, VirtualRoot]));
    types = som
        .pathForLeafState(HandleLamp)!
        .path
        .map((sd) => sd.stateType)
        .toList();
    expect(types, equals([HandleLamp, CleanAir, MaintainAir, VirtualRoot]));
    types = som
        .pathForLeafState(WaitForGoodAir)!
        .path
        .map((sd) => sd.stateType)
        .toList();
    expect(types, equals([WaitForGoodAir, CleanAir, MaintainAir, VirtualRoot]));
    log('done1');
    log('done2');
  }, skip: false);

  test('join', () async {
    final watcher = MockWatcher();
    final machine = await createMachine(watcher);
    expect(await machine.isInState<MaintainAir>(), equals(true));
    expect(await machine.isInState<MonitorAir>(), equals(true));
    verify(watcher.onEnter(MonitorAir, machine.initialEvent));

    /// trigger the fork
    machine.applyEvent(onBadAir);
    await machine.complete;
    expect(await machine.isInState<HandleFan>(), equals(true));
    expect(await machine.isInState<HandleLamp>(), equals(true));
    expect(await machine.isInState<CleanAir>(), equals(true));
    expect(await machine.isInState<MaintainAir>(), equals(true));

    verify(watcher.onExit(MonitorAir, onBadAir)).called(1);
    verify(watcher.onEnter(HandleFan, onBadAir)).called(1);
    verify(watcher.onEnter(HandleLamp, onBadAir)).called(1);
    verify(watcher.onEnter(WaitForGoodAir, onBadAir)).called(1);

    /// trigger the join
    machine.applyEvent(onFanRunning);
    await machine.complete;
    expect(await machine.isInState<HandleFan>(), equals(true));
    expect(await machine.isInState<HandleLamp>(), equals(true));
    expect(await machine.isInState<CleanAir>(), equals(true));
    expect(await machine.isInState<MaintainAir>(), equals(true));

    machine.applyEvent(onLampOn);
    await machine.complete;
    expect(await machine.isInState<HandleFan>(), equals(true));
    expect(await machine.isInState<HandleLamp>(), equals(true));
    expect(await machine.isInState<CleanAir>(), equals(true));
    expect(await machine.isInState<MaintainAir>(), equals(true));

    machine.applyEvent(onGoodAir);
    await machine.complete;
    expect(await machine.isInState<MonitorAir>(), equals(true));

    verify(watcher.onExit(HandleFan, onFanRunning)).called(1);
    verify(watcher.onExit(HandleLamp, onLampOn)).called(1);
    verify(watcher.onExit(WaitForGoodAir, onGoodAir)).called(1);
    verify(watcher.onEnter(MonitorAir, onGoodAir)).called(1);

    /// check that no extraneous actions were performed.
    verifyNoMoreInteractions(watcher);

    final som = machine.stateOfMind;
    final paths = som.activeLeafStates();
    expect(paths.length, equals(1));
    final types = som
        .pathForLeafState(MonitorAir)!
        .path
        .map((sd) => sd.stateType)
        .toList();

    expect(types, equals([MonitorAir, MaintainAir, VirtualRoot]));

    log(som.toString());
  }, skip: false);

  test('export', () async {
    final watcher = MockWatcher();
    await core.withTempDirAsync((tempDir) async {
      final pathTo = join(tempDir, 'cleaning_air_test.smcat');
      (await createMachine(watcher)).export(pathTo);
      final lines =
          read(pathTo).toList().reduce((value, line) => value += '\n$line');

      expect(lines, equals(_smcGraph));
    });
  }, skip: false);
}

Future<StateMachine> createMachine(MockWatcher watcher) async {
  late StateMachine machine;

  // used during debugging
  // ignore: unused_local_variable
  var lightOn = false;
  // used during debugging
  // ignore: unused_local_variable
  var fanOn = false;

  // used during debugging
  // ignore: join_return_with_assignment
  machine = await StateMachine.create((g) => g
    ..initialState<MaintainAir>()
    ..state<MaintainAir>((b) => b
      ..state<MonitorAir>((b) => b
        ..onEnter((s, e) => watcher.onEnter(s, e))
        ..onExit((s, e) => watcher.onExit(s, e))
        ..onFork<OnBadAir>(
            (b) => b
              ..target<HandleFan>()
              ..target<HandleLamp>()
              ..target<WaitForGoodAir>(),
            condition: (e) => e.quality < 10))
      ..coregion<CleanAir>((b) => b
        ..state<HandleFan>((b) => b
          ..onEnter((s, e) async {
            fanOn = true;
            await watcher.onEnter(s, e);
          })
          ..onExit((s, e) async {
            fanOn = false;
            await watcher.onExit(s, e);
          })
          ..onJoin<OnFanRunning, MonitorAir>(condition: ((e) => e.speed > 5))
          ..state<FanOff>((b) => b
            ..on<OnTurnFanOn, FanOn>(sideEffect: (e) async => lightOn = true))
          ..state<FanOn>((b) => b
            ..onEnter((s, e) async => machine.applyEvent(OnFanRunning()))
            ..on<OnTurnFanOff, FanOff>(
                sideEffect: (e) async => lightOn = false)))
        ..state<HandleLamp>((b) => b
          ..onEnter((s, e) async {
            lightOn = true;
            await watcher.onEnter(s, e);
          })
          ..onExit((s, e) async {
            lightOn = false;
            await watcher.onExit(s, e);
          })
          ..onJoin<OnLampOn, MonitorAir>()
          ..state<LampOff>((b) => b
            ..on<OnTurnLampOn, LampOn>(sideEffect: (e) async => lightOn = true))
          ..state<LampOn>((b) => b
            ..onEnter((s, e) async => machine.applyEvent(OnLampOn()))
            ..on<OnTurnLampOff, LampOff>(
                sideEffect: (e) async => lightOn = false)))
        ..state<WaitForGoodAir>((b) => b
          ..onEnter((s, e) => watcher.onEnter(s, e))
          ..onExit((s, e) => watcher.onExit(s, e))
          ..onJoin<OnGoodAir, MonitorAir>())))
    ..onTransition((s, e, st) {}));

  return machine;
}

var _smcGraph = '''
MaintainAir {
	MonitorAir {
		MonitorAir => ]MonitorAir.fork : OnBadAir;
		]MonitorAir.fork => HandleFan ;
		]MonitorAir.fork => HandleLamp ;
		]MonitorAir.fork => WaitForGoodAir ;
	},
	CleanAir.parallel [label="CleanAir"] {
		HandleFan {
			FanOff {
				FanOff => FanOn : OnTurnFanOn;
			},
			FanOn {
				FanOn => FanOff : OnTurnFanOff;
			};
			FanOff.initial => FanOff;
		},
		HandleLamp {
			LampOff {
				LampOff => LampOn : OnTurnLampOn;
			},
			LampOn {
				LampOn => LampOff : OnTurnLampOff;
			};
			LampOff.initial => LampOff;
		},
		WaitForGoodAir;
		HandleFan => ]MonitorAir.join : OnFanRunning;
		HandleLamp => ]MonitorAir.join : OnLampOn;
		WaitForGoodAir => ]MonitorAir.join : OnGoodAir;
		]MonitorAir.join => MonitorAir ;
	};
	MonitorAir.initial => MonitorAir;
};
initial => MaintainAir : MaintainAir;''';

class MonitorAir extends State {}

class CleanAir extends State {}

class HandleFan extends State {}

class FanOn extends State {}

class FanOff extends State {}

class HandleLamp extends State {}

class LampOff extends State {}

class LampOn extends State {}

class WaitForGoodAir extends State {}

class MaintainAir extends State {}

class OnBadAir extends Event {
  OnBadAir(this.quality);
  int quality;
}

class OnTurnLampOff extends Event {}

class OnTurnLampOn extends Event {}

class OnLampOn extends Event {}

class OnTurnFanOff extends Event {}

class OnTurnFanOn extends Event {}

class OnFanRunning extends Event {
  int get speed => 6;
}

class OnGoodAir extends Event {}
