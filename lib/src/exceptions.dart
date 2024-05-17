import 'definitions/state_definition.dart';
import 'state_of_mind.dart';
import 'types.dart';

/// When creating the statemachine a state has defined
/// an Event without a condition and it is not
/// the last event defined for the state.
class NullConditionMustBeLastException implements Exception {
  NullConditionMustBeLastException(this.eventType);
  Type eventType;

  @override
  String toString() =>
      '''The Event $eventType already has a transition with a null 'condition'. Only one is allowed''';
}

/// You called stateMachine.applyEvent with an event that is not
/// defined in a transition
/// for the current state.
class InvalidTransitionException implements Exception {
  InvalidTransitionException(this.stateOfMind, this.event);
  Event event;
  StateOfMind stateOfMind;

  @override
  String toString() =>
      '''There is no transition for Event ${event.runtimeType} from the State $stateOfMind.''';
}

/// You defined a transition 'on', 'fork', 'join' with a target state
///  which is not know to the
/// state engine.
class UnknownStateException implements Exception {
  UnknownStateException(this.message);
  String message;

  @override
  String toString() => message;
}

/// You have passed a State as an initialState that isn't either a
///  top level state or a leaf state.
class InvalidInitialStateException implements Exception {
  InvalidInitialStateException(this.message);
  String message;

  @override
  String toString() => message;
}

/// YOu have tried to define the same state twice.
class DuplicateStateException implements Exception {
  DuplicateStateException(StateDefinition<State> state)
      : message =
            '''The state ${state.stateType} is already in use. Every State must be unique.''';
  String message;

  @override
  String toString() => message;
}

/// The statemachine has been defined in an invalid fashion.
class InvalidStateMachine implements Exception {
  InvalidStateMachine(this.message);
  String message;

  @override
  String toString() => message;
}

/// An onJoin statement was used incorrectly.
class JoinWithNoCoregionException implements Exception {
  JoinWithNoCoregionException(this.message);
  String message;

  @override
  String toString() => message;
}

/// You tried to get the parent of a StatePath that
/// is just a VirtualRoot.
class NoParentException implements Exception {
  NoParentException(this.message);
  String message;

  @override
  String toString() => message;
}
