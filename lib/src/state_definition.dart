import 'transition.dart';

import 'event_choices.dart';
import 'exceptions.dart';
import 'state_machine.dart';

class StateDefinition<S extends State> {
  StateDefinition(this.stateType);

  final Type stateType;

  final Map<Type, EventChoices> transitions = {};

  /// Throws an [InvalidTransitionException] if there is no transition
  /// for the passed event out of the current state.
  TransitionDefinition getTransition<E extends Event>(S state, E event) {
    var eventChoices = transitions[event.runtimeType];

    if (eventChoices == null) {
      throw InvalidTransitionException(state, event);
    }

    return eventChoices.getTransition(state, this, event);
  }

  /// callback used when we enter this [State].
  /// Provide provide a default no-op implementation.
  OnEnter onEnter = (State toState, Event event) {};

  /// callback used when we exiting this [State].
  /// Provide provide a default no-op implementation.
  OnExit onExit = (State fromState, Event event) {};
}
