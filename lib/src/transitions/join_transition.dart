import 'package:fsm2/src/exceptions.dart';
import 'package:fsm2/src/virtual_root.dart';

import '../definitions/join_definition.dart';
import '../definitions/state_definition.dart';
import '../types.dart';
import 'transition_definition.dart';

/// A Join
/// [E] the event that triggers this transition
/// [S] the state that we will transition to once all other Joins are triggered
///  for the parent [coregion]
class JoinTransitionDefinition<S extends State, E extends Event, TOSTATE extends State>
    extends TransitionDefinition<E> {
  final JoinDefinition definition;

  /// The ancestor coregion this join is associated with.
  StateDefinition coRegion;

  /// For a Join transition the [toStateDefinition] is the parent [coregion].
  JoinTransitionDefinition(
    StateDefinition<State> parentStateDefinition,
    GuardCondition<E> condition,
    SideEffect sideEffect,
  )   : definition = JoinDefinition(TOSTATE),
        super(parentStateDefinition, sideEffect: sideEffect, condition: condition) {
    definition.addEvent(E);

    var parent = parentStateDefinition;

    while (!parent.isCoRegion && parent.stateType != VirtualRoot) {
      parent = parent.parent;
    }

    if (parent.stateType == VirtualRoot) {
      throw OnJoinException('onJoin for ${parentStateDefinition.stateType} MUST have a coregion anscestor.');
    }
  }

  @override
  List<Type> get targetStates => [definition.toState];

  @override
  List<Type> get triggerEvents => definition.events;
}
