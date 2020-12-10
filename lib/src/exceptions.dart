import 'definitions/state_definition.dart';

import 'state_of_mind.dart';
import 'types.dart';

/// When creating the statemachine a state has defined an Event without a condition and it is not
/// the last event defined for the state.
class NullConditionMustBeLastException implements Exception {
  Type eventType;
  NullConditionMustBeLastException(this.eventType);

  @override
  String toString() =>
      "The Event $eventType already has a transition with a null 'condition'. Only one is allowed";
}

/// You called stateMachine.applyEvent with an event that is not defined in a transition
/// for the current state.
class InvalidTransitionException implements Exception {
  Event event;
  StateOfMind stateOfMind;
  InvalidTransitionException(this.stateOfMind, this.event);

  @override
  String toString() =>
      'There is no transition for Event ${event.runtimeType} from the State $stateOfMind.';
}

/// You defined a transition 'on', 'fork', 'join' with a target state which is not know to the
/// state engine.
class UnknownStateException implements Exception {
  String message;

  UnknownStateException(this.message);

  @override
  String toString() => message;
}

/// You have passed an State as an initialState that isn't either a top level state or a leaf state.
class InvalidInitialStateException implements Exception {
  String message;

  InvalidInitialStateException(this.message);

  @override
  String toString() => message;
}

/// YOu have tried to define the same state twice.
class DuplicateStateException implements Exception {
  String message;

  DuplicateStateException(StateDefinition<State> state)
      : message =
            'The state ${state.stateType} is already in use. Every State must be unique.';

  @override
  String toString() => message;
}

/// The statemachine has been defined in an invalid fashion.
class InvalidStateMachine implements Exception {
  String message;

  InvalidStateMachine(this.message);

  @override
  String toString() => message;
}

/// An onJoin statement was used incorrectly.
class OnJoinException implements Exception {
  String message;

  OnJoinException(this.message);

  @override
  String toString() => message;
}
