import 'package:fsm2/src/types.dart';

import 'cleaning_air_test.dart';

typedef GuardCondition<E extends Event> = bool Function(E event);

class Fork<E extends Event> {
  Fork(this.condition);

  GuardCondition<E> condition;

  bool doIt(E event) => condition(event);
}

void main() {
  final fork = Fork<OnBadAir>((e) => e.quality < 10);

  print(fork.doIt(OnBadAir(5)));
}
