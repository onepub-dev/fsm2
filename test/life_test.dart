import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';
import 'package:dcli/dcli.dart' hide equals;

StateMachine machine;
void main() {
  test('export', () async {
    _createMachine();
    await machine.analyse();
    await machine.export('test/gv/life_test.gv');

    var graph = '''digraph fsm2 {
	InitialState [shape=point];
	InitialState -> Twinkle;
	Twinkle -> Gestation [label="Conception"];
	Gestation -> Baby [label="Born"];
	Baby -> Teenager [label="Puberty"];
	Teenager -> Adult [label="GetDrunk"];
	Adult -> Dead [label="Death"];
	Dead -> TerminalState1;
// terminal states
TerminalState1 [shape=point];
}''';

    var lines = read('test/gv/life_test.gv')
        .toList()
        .reduce((value, line) => value += '\n' + line);

    expect(lines, equals(graph));
  });
}

void _createMachine() {
  machine = StateMachine.create((g) => g
    ..initialState<Twinkle>()
    ..state<Twinkle>((b) => b..on<Conception, Gestation>())
    ..state<Gestation>((b) => b..on<Born, Baby>())
    ..state<Baby>((b) => b..on<Puberty, Teenager>())
    ..state<Teenager>((b) => b..on<GetDrunk, Adult>())
    ..state<Adult>((b) => b..on<Death, Dead>())
    ..state<Dead>((b) {}));
}

void turnFanOn() {}

void turnFanOff() {}

class Twinkle implements State {}

class Gestation implements State {}

class Baby implements State {}

class Teenager implements State {}

class Adult implements State {}

class Taxes implements State {}

class Dead implements State {}

class Adulthood implements State {}

class Conception implements Event {}

class Born implements Event {}

class Puberty implements Event {}

class GetDrunk implements Event {}

class Death implements Event {}
