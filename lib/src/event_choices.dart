import 'package:fsm2/src/transition_definition.dart';

import 'transition.dart';

import 'state_definition.dart';
import 'types.dart';

/// An [EventChoice] is used to store details
/// of an [State.on] or [State.onDynamic] event
/// transition.
/// If [State.on] was called then [toState] is used to store the
/// statically declared state transition.
/// If [State.onDynamic] was called then [eventHandler] is used
/// to store the callback function used to determine the
/// state transition.
class EventChoice<S extends State, E extends Event, TOSTATE extends State> {
  Condition<S, E> condition;

  /// Callback into the user code
  /// to determine the new [State]
  /// to transition to.
  EventHandler<E> eventHandler;

  Type toState;

  /// The [SideEffect] function to call when this choice is
  /// selected as the transition.
  SideEffect sideEffect;
}

class EventChoices<S extends State, E extends Event> {
  Type eventType;

  /// list of available choices for this Event.
  /// The choices are added in the order the '..on' method is called
  /// and evaluated in that order.
  /// The first Choice that evaluate to true is used to determine
  /// the transition and no further choices are evaulated.
  var eventChoices = <EventChoice<S, E, State>>[];

  /// gets the transition for the given [event] from [fromState]
  /// Conditions are applied to determine the correct transition.
  Future<TransitionDefinition> getTransition(Type fromState, StateDefinition fromStateDefinition, E event) async {
    for (var choice in eventChoices) {
      if (choice.condition == null || choice.condition(fromState, event)) {
        if (choice.eventHandler != null) {
          /// its a dynamic transition so:
          /// call back into user code to allow them to decide what
          /// the new [State] will be.
          var transition = await choice.eventHandler(fromState, event);
          return ValidTransitionDefinition(
            S,
            fromStateDefinition,
            E,
            transition,
          );
        } else {
          /// static transition
          return ValidTransitionDefinition(
              S, fromStateDefinition, E, createTransition(choice.toState, sideEffect: choice.sideEffect));
        }
      }
    }
    return NoOpTransitionDefinition(S, fromStateDefinition, E);
  }
}


