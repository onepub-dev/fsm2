import 'types.dart';

class ForkDefinition<E extends Event> {
  ForkDefinition();

  var stateTargets = <Type>[];

  void addTarget(Type s) {
    stateTargets.add(s);
  }
}
