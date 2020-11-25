import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';

StateMachine machine;
void main() {
  test('export', () async {
    _createMachine();
    await machine.analyse();
    await machine.export('test/test.gv');
  }, skip: false);
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
