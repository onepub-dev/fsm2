import 'state_machine.dart';

class NullChoiceMustBeLastException implements Exception {
  Type eventType;
  NullChoiceMustBeLastException(this.eventType);

  @override
  String toString() => "The Event ${eventType} already has a transition with a null 'choice'. Only one is allowed";
}

class InvalidTransitionException implements Exception {
  State fromState;
  Event event;
  InvalidTransitionException(this.fromState, this.event);

  @override
  String toString() => 'There is no tranisition for Event ${event.runtimeType} from the State ${fromState.runtimeType}';
}

class UnregisteredStateException implements Exception {
  String message;

  UnregisteredStateException(this.message);

  @override
  String toString() => message;
}
