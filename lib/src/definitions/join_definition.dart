import '../types.dart';

class JoinDefinition<S extends State> {
  /// The state this join is targeting.
  final Type toState;

  /// The set of events that must occur (when in the owning state) for this join
  /// to fire.
  final events = <Type>[];

  JoinDefinition(this.toState);

  void addEvent(Type e) {
    events.add(e);
  }
}
