import 'package:fsm2/src/definitions/co_region_definition.dart';
import 'package:fsm2/src/exceptions.dart';

import '../definitions/join_definition.dart';
import '../definitions/state_definition.dart';
import '../graph.dart';
import '../types.dart';
import 'transition_definition.dart';
import 'transition_notification.dart';

/// A Join
/// [E] the event that triggers this transition
/// [S] the state that we will transition to once all other Joins are triggered
///  for the parent [coregion]
class JoinTransitionDefinition<S extends State, E extends Event,
    TOSTATE extends State> extends TransitionDefinition<E> {
  final JoinDefinition definition;

  // bool _hasTriggered = false;

  /// The ancestor coregion this join is associated with.
  late CoRegionDefinition coregion;

  /// For a Join transition the 'to' State is the parent [coregion].
  JoinTransitionDefinition(
    StateDefinition<State> parentStateDefinition,
    GuardCondition<E>? condition,
    SideEffect? sideEffect,
  )   : definition = JoinDefinition(TOSTATE),
        super(parentStateDefinition,
            sideEffect: sideEffect, condition: condition) {
    definition.addEvent(E);

    var parent = parentStateDefinition;

    while (!parent.isCoRegion && !parent.isVirtualRoot) {
      parent = parent.parent!;
    }

    /// we need to register the join with the owning co-region
    if (parent is CoRegionDefinition) {
      coregion = parent;
      parent.registerJoin(this);
    } else {
      throw JoinWithNoCoregionException(
          'onJoin for ${parentStateDefinition.stateType} MUST have a coregion anscestor.');
    }
  }

  /// used to trigger the last event that triggered this transition.
  late final E _triggeredBy;

  @override
  bool canTrigger(E event) {
    _triggeredBy = event;
    return coregion.canTrigger(E);
  }

  @override
  List<Type> get targetStates => [definition.toState];

  @override
  List<Type> get triggerEvents => definition.events;

  /// When a join is triggered we need to reflect that multiple transitions will
  /// now occur. One for each 'onJoin' statement each of which can belong to a different
  /// state.
  ///
  /// returns the list of transitions that this definition causes when triggered.
  @override
  List<TransitionNotification> transitions(
      Graph graph, StateDefinition? from, Event event) {
    final List<TransitionNotification> transitions = <TransitionNotification>[];

    // Gather all of the other transition in the coregion defined by onJoins
    // TODO: what about states that don't have an onjoin do we need
    // create transitions for each of those?
    for (final join in coregion.joinTransitions) {
      final notification = join.buildTransitionNotification(graph);

      if (notification.event != event) {
        notification.skipEnter = true;
      }
      transitions.add(notification);
    }

    return transitions;
  }

  TransitionNotification<E> buildTransitionNotification(Graph graph) {
    // join only ever has one target state.
    final targetState = targetStates[0];
    final targetStateDefinition = graph.findStateDefinition(targetState);

    return TransitionNotification<E>(
        this, fromStateDefinition, _triggeredBy, targetStateDefinition);
  }
}
