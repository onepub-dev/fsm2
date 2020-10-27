import '../fsm.dart';
import 'state_definition.dart';

class Graph {
  Graph(this.initialState, this.stateDefinitions, this.onTransitionListeners);

  final State initialState;
  final Map<Type, StateDefinition> stateDefinitions;
  final List<TransitionListener> onTransitionListeners;
}
