import 'state_machine.dart';
import 'transition.dart';

import 'state_definition.dart';

class EventChoice<S extends State, E extends Event> {
  Condition<S, E> condition;

  /// Callback into the user code
  /// to determine the new [State]
  /// to transition to.
  EventHandler<S, E> requestTransition;
}

class EventChoices<S extends State, E extends Event> {
  Type eventType;

  /// list of available choices for this Event.
  /// The choices are added in the order the '..on' method is called
  /// and evaluated in that order.
  /// The first Choice that evaluate to true is used to determine
  /// the transition and no further choices are evaulated.
  var eventChoices = <EventChoice<S, E>>[];

  TransitionDefinition getTransition(
      S fromState, StateDefinition fromStateDefinition, E event) {
    for (var choice in eventChoices) {
      if (choice.condition == null || choice.condition(fromState, event)) {
        /// call back into user code to allow them to decied what
        /// the new [State] will be.
        var transition = choice.requestTransition(fromState, event);
        return ValidTransitionDefinition(
          fromState,
          fromStateDefinition,
          event,
          transition,
        );
      }
    }
    return NoOpTransitionDefinition(fromState, fromStateDefinition, event);
  }
}

typedef Condition<S extends State, E extends Event> = bool Function(
    S state, E event);
