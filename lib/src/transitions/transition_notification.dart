import '../definitions/state_definition.dart';
import '../types.dart';
import 'transition_definition.dart';

class TransitionNotification<E extends Event> {
  TransitionNotification(this.definition, this.from, this.event, this.to);
  TransitionDefinition<E> definition;
  StateDefinition? from;
  E event;
  StateDefinition? to;

  /// Some transitions (fork/join) cause multiple transitions to/from a state.
  /// We only want to trigger the onEnter/onExit methods once so these
  /// flags allow then onEnter/onExit methods to be skipped.
  bool skipEnter = false;
  bool skipExit = false;
}
