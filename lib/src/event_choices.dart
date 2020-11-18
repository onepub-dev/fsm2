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
  /// The condition that must be met for this [EventChoice] to be triggered.
  /// If [condition] is null then it always evaluates to true and the
  /// event will be triggered. Null conditions are always the last [condition]
  /// to be evaulated against an event, so any other [condition] that returns true
  /// will be fired in preference to a null [condition].
  GuardCondition<S, E> condition;

  /// Callback into the user code
  /// to determine the new [State]
  /// to transition to.
  /// Either an [eventHandler] or a [toState] must be passed but not both.
  /// An [eventHandler] is set by calling the [onDynamic] method against a [State]
  EventHandler<E> eventHandler;

  /// If this [EventChoice] is trigger this will be the new [State]
  /// the FSM. If [toState] is null then there MUST be an [eventHandler]
  /// which will be called to determine the new [State].
  /// Either an [eventHandler] or a [toState] must be passed but not both.
  /// [toState] is set by calling the [on] method against a [State]
  Type toState;

  /// The [SideEffect] function to call when this choice is
  /// selected as the transition.
  SideEffect sideEffect;

  /// true if this [EventChoice] was statically defined with the [on]
  /// transition builder.
  bool get isStatic => toState != null;
}

class EventChoices<S extends State, E extends Event> {
  Type eventType;

  /// list of available choices for this Event.
  /// The choices are added in the order the '..on' method is called
  /// and evaluated in that order.
  /// The first Choice that evaluate to true is used to determine
  /// the transition and no further choices are evaulated.
  var eventChoices = <EventChoice<S, E, State>>[];

  /// Evaluates each guard condition for the given [event]  from [fromState]
  ///
  /// Conditions are applied to determine which transition occurs.
  ///
  /// If no condition allows the transition to fire then we return
  /// a [NoOpTransitionDefinition] which result in no state transition occuring.
  ///
  Future<TransitionDefinition> evaluateConditions(Type fromState, StateDefinition fromStateDefinition, E event) async {
    assert(eventChoices.isNotEmpty);
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
