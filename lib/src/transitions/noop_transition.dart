import '../definitions/state_definition.dart';
import '../graph.dart';
import '../state_machine.dart';
import '../state_of_mind.dart';
import '../types.dart';
import 'transition_definition.dart';
import 'transition_notification.dart';

/// When a valid event is passed to [StateMachine.applyEvent]
///  but no [condition] method
/// evaluated to true so no transition will occur.
/// Also used by Join transitions when not all of the
///  join prerequisite events have been met.
///
/// The StateMachine will stay in [S] state.
class NoOpTransitionDefinition<S extends State, E extends Event>
    extends TransitionDefinition<E> {
  /// no transition so [fromStateDefinition] == [targetStates].
  NoOpTransitionDefinition(super.fromStateDefinition, this.eventType);
  final Type eventType;
  @override
  Future<StateOfMind> trigger(Graph graph, StateOfMind stateOfMind,
          TransitionNotification transition,
          {bool applySideEffects = true}) async =>
      Future.value(stateOfMind);

  @override
  List<Type> get targetStates => [fromStateDefinition.stateType];

  @override
  List<Type> get triggerEvents => [eventType];

  @override
  List<TransitionNotification> transitions(
          Graph graph, StateDefinition? from, Event event) =>
      <TransitionNotification>[];
}
