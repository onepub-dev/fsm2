import 'state_definition.dart';
import 'state_machine.dart';
import 'transition.dart';

class Graph {
  Graph(this.initialState, this.stateDefinitions, this.onTransitionListeners);

  final State initialState;
  final Map<Type, StateDefinition> stateDefinitions;
  final List<TransitionListener> onTransitionListeners;
}
