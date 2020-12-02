import '../definitions/state_definition.dart';

import '../types.dart';

class JoinDefinition<S extends State> {
  JoinDefinition(this.toState);

  /// The Type of the [State] that this [StateDefinition] is for.
  final Type toState;

  final events = <Type>[];

  void addEvent(Type e) {
    events.add(e);
  }
}
