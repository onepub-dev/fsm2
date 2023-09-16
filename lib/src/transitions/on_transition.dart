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
  OnTransitionDefinition(super.stateDefinition, GuardCondition<E> condition,
      this.toState, SideEffect<E>? sideEffect,
      {super.conditionLabel, super.sideEffectLabel})
      : super(condition: condition, sideEffect: sideEffect);

  /// If this [OnTransitionDefinition] is trigger [toState]
  /// will be the new [State]
  Type toState;

  @override
  List<Type> get targetStates => [toState];

  @override
  List<Type> get triggerEvents => [E];

  /// list of transitions that this definition will cause when triggered.
  /// Each transition may need to overload this if anything other than
  /// a single transition occurs.
  @override
  List<TransitionNotification> transitions(
      Graph graph, StateDefinition? from, Event event) {
    final transitions = <TransitionNotification>[
      buildTransitionNotification(graph, from, event as E)
    ];
    return transitions;
  }

  TransitionNotification<E> buildTransitionNotification(
      Graph graph, StateDefinition<State>? from, E event) {
    final targetDefinition = graph.findStateDefinition(toState);

    return TransitionNotification<E>(this, from, event, targetDefinition);
  }
}
