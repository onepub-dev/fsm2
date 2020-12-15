import 'package:fsm2/src/definitions/co_region_definition.dart';
import 'package:fsm2/src/exceptions.dart';

import '../definitions/join_definition.dart';
import '../definitions/state_definition.dart';
import '../types.dart';
import 'transition_definition.dart';

/// A Join
/// [E] the event that triggers this transition
/// [S] the state that we will transition to once all other Joins are triggered
///  for the parent [coregion]
class JoinTransitionDefinition<S extends State, E extends Event,
    TOSTATE extends State> extends TransitionDefinition<E> {
  final JoinDefinition definition;

  // bool _hasTriggered = false;

  /// The ancestor coregion this join is associated with.
  StateDefinition coRegion;

  /// For a Join transition the [toStateDefinition] is the parent [coregion].
  JoinTransitionDefinition(
    StateDefinition<State> parentStateDefinition,
    GuardCondition<E> condition,
    SideEffect sideEffect,
  )   : definition = JoinDefinition(TOSTATE),
        super(parentStateDefinition,
            sideEffect: sideEffect, condition: condition) {
    definition.addEvent(E);

    var parent = parentStateDefinition;

    while (!parent.isCoRegion && !parent.isVirtualRoot) {
      parent = parent.parent;
    }

    /// we need to register the join with the owning co-region
    if (parent is CoRegionDefinition) {
      parent.registerJoin(this);
    } else {
      throw JoinWithNoCoregionException(
          'onJoin for ${parentStateDefinition.stateType} MUST have a coregion anscestor.');
    }
  }

  @override
  bool canTrigger(E event) {
    return coRegion.canTrigger(E);
  }

  // /// Applies [event] to the  current statemachine and returns the resulting
  // /// [StateOfMind].
  // ///
  // /// As the statemachine can be in multiple states the [state] argument indicates what
  // /// [State] the [event] is to be processed against.
  // Future<StateOfMind> trigger(
  //     Graph graph, StateOfMind stateOfMind, Type fromState, Event event) async {
  //   /// we need to reset the set of activated triggers if we leave the parent state.
  //   /// Where do we store the set of 'triggered' events.
  //   /// StateOfMind or simply in this class.
  //   /// This join def is unique in the statemachine so probably no reason we can't store it
  //   /// here. Having said that the 'stateOfMind' is sort of the holder of the current 'memory'
  //   /// of the statemachin so it might make a better spot.
  //   /// If we do how do we register this transition with the state of mind.
  //   ///
  //   /// Also how do we get this reset. It needs to be reset either
  //   /// each time we enter the co-region or when we exit it.
  //   ///
  //   /// The onEnter/onExit methods are used for this but they are public.
  //   /// Should we have a private set.
  //   /// We could also listen to transition events.
  //   /// Or the co-region could simply send us a reset when it sees an onExit.

  //   bool fullyJoined = false;
  //   _triggeredEvents.add(event);
  // }

  @override
  List<Type> get targetStates => [definition.toState];

  @override
  List<Type> get triggerEvents => definition.events;

  /// The set of events that have been triggered for this join.
  /// The join will not trigger until all of its events have been triggered.
  final _triggeredEvents = <Type>{};

  /// Called whenver the parent co-region is entered so that we can reset
  /// the set of triggered events.
  void reset() {
    _triggeredEvents.clear();
  }
}
