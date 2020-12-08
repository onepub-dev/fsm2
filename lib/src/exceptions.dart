import 'definitions/state_definition.dart';

import 'state_of_mind.dart';
import 'types.dart';

class NullChoiceMustBeLastException implements Exception {
  Type eventType;
  NullChoiceMustBeLastException(this.eventType);

  @override
  String toString() =>
      "The Event $eventType already has a transition with a null 'choice'. Only one is allowed";
}

class InvalidTransitionException implements Exception {
  Event event;
  StateOfMind stateOfMind;
  InvalidTransitionException(this.stateOfMind, this.event);

  @override
  String toString() =>
      'There is no transition for Event ${event.runtimeType} from the State $stateOfMind.';
}

class UnknownStateException implements Exception {
  String message;

  UnknownStateException(this.message);

  @override
  String toString() => message;
}

class InvalidInitialStateException implements Exception {
  String message;

  InvalidInitialStateException(this.message);

  @override
  String toString() => message;
}

// class InvalidNestedStateException implements Exception {
//   String message;

//   InvalidNestedStateException(StateDefinition<State> child, StateDefinition<State> parent)
//       : message = 'The child state ${child.stateType} MUST NOT have the same type as a parent state';

//   @override
//   String toString() => message;
// }

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
