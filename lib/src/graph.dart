import 'package:fsm2/src/exceptions.dart';

import 'state_definition.dart';
import 'types.dart';

class Graph {
  Graph(this.initialState, List<StateDefinition> stateDefinitions, this.onTransitionListeners)
      : topStateDefinitions = stateDefinitions,
        stateDefinitions = expandStateDefinitions(stateDefinitions);

  final Type initialState;

  /// a full set of stateDefinitions including nested and co-states.
  final Map<Type, StateDefinition> stateDefinitions;

  /// a subset of [stateDefinitions] that only includes the top level states.
  final List<StateDefinition> topStateDefinitions;
  final List<TransitionListener> onTransitionListeners;

  /// scans down the [StateDefinition] tree looking for a matching
  /// state.
  StateDefinition findStateDefinition(Type runtimeType) => stateDefinitions[runtimeType];

  static Map<Type, StateDefinition> expandStateDefinitions(List<StateDefinition<State>> stateDefinitions) {
    var definitions = <Type, StateDefinition>{};

    for (var stateDefinition in stateDefinitions) {
      addStateDefinition(definitions, stateDefinition);

      var nested = stateDefinition.nestedStateDefinitions;
      for (var nestedStateDefinition in nested) {
        addStateDefinition(definitions, nestedStateDefinition);
      }
    }
    return definitions;
  }

  static void addStateDefinition(
      Map<Type, StateDefinition<State>> stateDefinitions, StateDefinition<State> stateDefinition) {
    if (stateDefinitions.containsKey(stateDefinition.stateType)) {
      throw DuplicateStateException(stateDefinition);
    }
    stateDefinitions[stateDefinition.stateType] = stateDefinition;
  }
}
