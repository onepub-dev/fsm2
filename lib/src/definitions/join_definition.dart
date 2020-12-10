import '../types.dart';

class JoinDefinition<S extends State> {
  JoinDefinition(this.toState);

  /// The state this join is targeting.
  final Type toState;

  final events = <Type>[];

  void addEvent(Type e) {
    events.add(e);
  }
}
