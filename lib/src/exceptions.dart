import 'package:fsm2/src/state_definition.dart';

import 'types.dart';

class NullChoiceMustBeLastException implements Exception {
  Type eventType;
  NullChoiceMustBeLastException(this.eventType);

  @override
  String toString() => "The Event ${eventType} already has a transition with a null 'choice'. Only one is allowed";
}

class InvalidTransitionException implements Exception {
  Type fromState;
  Event event;
  InvalidTransitionException(this.fromState, this.event);

  @override
  String toString() => 'There is no tranisition for Event ${event.runtimeType} from the State ${fromState}.';
}

class UnknownStateException implements Exception {
  String message;

  UnknownStateException(this.message);

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
      : message = 'The state ${state.stateType} is already in use. Every State must be unique.';

  @override
  String toString() => message;
}
