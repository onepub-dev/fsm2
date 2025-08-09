import '../types.dart';

class ForkDefinition<E extends Event> {
  /// List of starts that are the targets of this fork.
  final stateTargets = <Type>[];

  ForkDefinition();

  void addTarget(Type s) {
    stateTargets.add(s);
  }
}
