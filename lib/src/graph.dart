import 'state_definition.dart';
import 'types.dart';

class Graph {
  Graph(this.initialState, List<StateDefinition> stateDefinitions, this.onTransitionListeners)
      : stateDefinitions = expandStateDefinitions(stateDefinitions);

  final Type initialState;

  /// a full set of stateDefinitions including nested and co-states.
  final Map<Type, StateDefinition> stateDefinitions;
  final List<TransitionListener> onTransitionListeners;

  /// scans down the [StateDefinition] tree looking for a matching
  /// state.
  StateDefinition findStateDefinition(Type runtimeType) => stateDefinitions[runtimeType];

  static Map<Type, StateDefinition> expandStateDefinitions(List<StateDefinition<State>> stateDefinitions) {
    var definitions = <Type, StateDefinition>{};

    for (var stateDefinition in stateDefinitions) {
      definitions[stateDefinition.stateType] = stateDefinition;

      var nested = stateDefinition.nestedStateDefinitions();
      for (var nestedStateDefinition in nested) {
        definitions[nestedStateDefinition.stateType] = nestedStateDefinition;
      }
    }
    return definitions;
  }
}
