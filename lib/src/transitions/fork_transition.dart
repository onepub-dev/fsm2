import '../fork_definition.dart';
import '../state_definition.dart';
import '../types.dart';
import 'transition_definition.dart';

class ForkTransitionDefinition<S extends State, E extends Event>
    extends TransitionDefinition<S, E> {
  /// List of state types that are the target of this fork.

  final ForkDefinition definition;
  ForkTransitionDefinition(StateDefinition stateDefinition, this.definition)
      : super(stateDefinition);

  @override
  List<Type> get targetStates => definition.stateTargets;

  @override
  List<Type> get triggerEvents => [E];
}
