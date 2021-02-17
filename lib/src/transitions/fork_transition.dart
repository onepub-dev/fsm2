import '../definitions/fork_definition.dart';
import '../definitions/state_definition.dart';
import '../graph.dart';
import '../types.dart';
import 'transition_definition.dart';
import 'transition_notification.dart';

class ForkTransitionDefinition<S extends State, E extends Event>
    extends TransitionDefinition<E> {
  /// List of state types that are the target of this fork.

  final ForkDefinition definition;
  ForkTransitionDefinition(StateDefinition stateDefinition, this.definition)
      : super(stateDefinition);

  @override
  List<Type> get targetStates => definition.stateTargets;

  @override

  /// A ForkDefintion only has a single triggerEvent.
  List<Type> get triggerEvents => [E];

  @override
  List<TransitionNotification> transitions(
      Graph graph, StateDefinition? from, Event event) {
    final transitions = <TransitionNotification>[];
    for (final targetState in targetStates) {
      final targetDefinition = graph.findStateDefinition(targetState);

      final notification =
          TransitionNotification(from, event, targetDefinition);
      if (notification.event != event) {
        notification.skipExit = true;
      }

      transitions.add(notification);
    }
    return transitions;
  }
}
