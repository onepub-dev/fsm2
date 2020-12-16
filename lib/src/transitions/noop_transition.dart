import '../definitions/state_definition.dart';
import '../graph.dart';
import '../state_of_mind.dart';
import '../types.dart';
import 'transition_definition.dart';
import 'transition_notification.dart';

/// Valid transition called by [event] but no [condition] method
/// evaluated to true so no transition will occur.
/// Also used by Join transitions when not all of the join prerequisite events have been met.
/// Machine stays in [state].
class NoOpTransitionDefinition<S extends State, E extends Event>
    extends TransitionDefinition<E> {
  final Type eventType;

  /// no transition so [fromState] == [targetStates].
  NoOpTransitionDefinition(StateDefinition fromStateDefinition, this.eventType)
      : super(fromStateDefinition);
  @override
  Future<StateOfMind> trigger(
      Graph graph, StateOfMind stateOfMind, TransitionNotification _) async {
    return Future.value(stateOfMind);
  }

  @override
  List<Type> get targetStates => [fromStateDefinition.stateType];

  @override
  List<Type> get triggerEvents => [eventType];

  @override
  List<TransitionNotification> transitions(
      Graph graph, StateDefinition from, Event event) {
    return <TransitionNotification>[];
  }
}
