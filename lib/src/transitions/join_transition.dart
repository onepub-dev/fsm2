import '../join_definition.dart';
import '../state_definition.dart';
import '../types.dart';
import 'transition_definition.dart';

/// A Join
class JoinTransitionDefinition<S extends State, E extends Event> extends TransitionDefinition<S, E> {
  @override
  List<Type> get targetStates => [definition.toState];

  final JoinDefinition definition;

  /// For a Join transition the [stateDefinition] is the parent costate.
  JoinTransitionDefinition(StateDefinition<S> stateDefinition, this.definition)
      : super(
          stateDefinition,
        );

  @override
  List<Type> get triggerEvents => definition.events;
}
