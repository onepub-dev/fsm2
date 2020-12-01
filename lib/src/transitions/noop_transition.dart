import '../graph.dart';
import '../state_definition.dart';
import '../state_of_mind.dart';
import '../types.dart';
import 'transition_definition.dart';

/// Valid transition called by [event] but no [condition] method
/// evaluated to true so no transition will occur.
/// Machine stays in [state].
class NoOpTransitionDefinition<S extends State, E extends Event> extends TransitionDefinition<E> {
  final Type eventType;

  /// no transition so [fromState] == [targetStates].
  NoOpTransitionDefinition(StateDefinition fromStateDefinition, this.eventType) : super(fromStateDefinition);
  @override
  Future<StateOfMind> trigger(Graph graph, StateOfMind stateOfMind, Type fromState, Event event) async {
    return Future.value(stateOfMind);
  }

  @override
  List<Type> get targetStates => [fromStateDefinition.stateType];

  @override
  List<Type> get triggerEvents => [eventType];
}
