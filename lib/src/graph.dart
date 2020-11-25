import 'package:fsm2/src/exceptions.dart';

import 'state_definition.dart';
import 'types.dart';

class Graph {
  Graph(this.initialState, this.topStateDefinitions, this.onTransitionListeners)
      : stateDefinitions = _expandStateDefinitions(topStateDefinitions);

  final Type initialState;

  /// a full set of stateDefinitions including nested and co-states.
  final Map<Type, StateDefinition> stateDefinitions;

  /// a subset of [stateDefinitions] that only includes the top level states.
  final List<StateDefinition> topStateDefinitions;

  /// List of listeners to call each time we transition to a new state.
  final List<TransitionListener> onTransitionListeners;

  /// scans down the [StateDefinition] tree looking for a matching
  /// state.
  StateDefinition findStateDefinition(Type runtimeType) =>
      stateDefinitions[runtimeType];

  /// wire the top state definitions into the stateDefinition map
  /// and into the [VirtualRoot]
  static Map<Type, StateDefinition> _expandStateDefinitions(
      List<StateDefinition<State>> topStateDefinitions) {
    var definitions = <Type, StateDefinition>{};

    addStateDefinition(definitions, VirtualRoot().definition);

    for (var stateDefinition in topStateDefinitions) {
      addStateDefinition(definitions, stateDefinition);

      /// wire the root states into the virtual root.
      VirtualRoot()
          .definition
          .childStateDefinitions[stateDefinition.stateType] = stateDefinition;

      var nested = stateDefinition.nestedStateDefinitions;
      for (var nestedStateDefinition in nested) {
        addStateDefinition(definitions, nestedStateDefinition);
      }
    }
    return definitions;
  }

  static void addStateDefinition(
      Map<Type, StateDefinition<State>> stateDefinitions,
      StateDefinition<State> stateDefinition) {
    if (stateDefinitions.containsKey(stateDefinition.stateType)) {
      throw DuplicateStateException(stateDefinition);
    }
    stateDefinitions[stateDefinition.stateType] = stateDefinition;
  }

  /// Get's the parent of the given state
  Type getParent(Type childState) {
    var def = findStateDefinition(childState);
    assert(def != null);

    return def.parent == null ? null : def.parent.stateType;
  }
}
