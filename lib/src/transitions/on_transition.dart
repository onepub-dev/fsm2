import '../builders/state_builder.dart';
import '../definitions/state_definition.dart';
import '../graph.dart';
import '../types.dart';
import 'transition_definition.dart';
import 'transition_notification.dart';

/// An [OnTransitionDefinition] is used to store details
/// of an transition defined by [StateBuilder.on]
class OnTransitionDefinition<S extends State, E extends Event,
    TOSTATE extends State> extends TransitionDefinition<E> {
  /// If this [OnTransitionDefinition] is trigger [toState] will be the new [State]
  Type toState;

  OnTransitionDefinition(StateDefinition stateDefinition,
      GuardCondition<E>? condition, this.toState, SideEffect<E>? sideEffect,
      {String? conditionLabel, String? sideEffectLabel})
      : super(stateDefinition,
            condition: condition,
            sideEffect: sideEffect,
            conditionLabel: conditionLabel,
            sideEffectLabel: sideEffectLabel);

  @override
  List<Type> get targetStates => [toState];

  @override
  // TODO: implement triggerEvents
  List<Type> get triggerEvents => [E];

  /// list of transitions that this definition will cause when triggered.
  /// Each transition may need to overload this if anything other than
  /// a single transition occurs.
  @override
  List<TransitionNotification> transitions(
      Graph graph, StateDefinition? from, Event event) {
    final transitions = <TransitionNotification>[];
    for (final targetState in targetStates) {
      final targetDefinition = graph.findStateDefinition(targetState);
      transitions.add(TransitionNotification(from, event, targetDefinition));
    }
    return transitions;
  }
}
