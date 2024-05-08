import 'package:dcli/dcli.dart';
import 'package:dcli_core/dcli_core.dart' as core;
import 'package:fsm2/fsm2.dart';
import 'package:path/path.dart' hide equals;
import 'package:test/test.dart';

late StateMachine machine;
void main() {
  test('export', () async {
    await core.withTempDirAsync((tempDir) async {
      final pathToTest = join(tempDir, 'life_test.smcat');

      await _createMachine();
      machine
        ..analyse()
        ..export(pathToTest);

      const graph = '''

Twinkle {
	Twinkle => Gestation : Conception;
},
Gestation {
	Gestation => Baby : Born;
},
Baby {
	Baby => Teenager : Puberty;
},
Teenager {
	Teenager => Adult : GetDrunk;
},
Adult {
	Adult => Dead : Death;
},
Dead;
initial => Twinkle : Twinkle;''';

      final lines =
          read(pathToTest).toList().reduce((value, line) => value += '\n$line');

      expect(lines, equals(graph));
    });
  });
}

Future<void> _createMachine() async {
  machine = await StateMachine.create((g) => g
    ..initialState<Twinkle>()
    ..state<Twinkle>((b) => b..on<Conception, Gestation>())
    ..state<Gestation>((b) => b..on<Born, Baby>())
    ..state<Baby>((b) => b..on<Puberty, Teenager>())
    ..state<Teenager>((b) => b..on<GetDrunk, Adult>())
    ..state<Adult>((b) => b..on<Death, Dead>())
    ..state<Dead>((b) {}));
}

class Twinkle implements State {}

class Gestation implements State {}

class Baby implements State {}

class Teenager implements State {}

class Adult implements State {}

// class Taxes implements State {}

class Dead implements State {}

// class Adulthood implements State {}

class Conception implements Event {}

class Born implements Event {}

class Puberty implements Event {}

class GetDrunk implements Event {}

class Death implements Event {}
