import 'package:fsm2/src/exceptions.dart';

import 'definitions/state_definition.dart';
import 'types.dart';
import 'virtual_root.dart';

class Graph {
  Graph(this.virtualRoot, this.initialState, this.topStateDefinitions,
      this.onTransitionListeners, this.initialStateLabel)
      : stateDefinitions =
            _expandStateDefinitions(virtualRoot, topStateDefinitions);

  StateDefinition<VirtualRoot> virtualRoot;
  Type initialState;
  String initialStateLabel;

  /// a full set of stateDefinitions including nested and coregions.
  final Map<Type, StateDefinition> stateDefinitions;

  /// a subset of [stateDefinitions] that only includes the top level states.
  final List<StateDefinition> topStateDefinitions;

  /// List of listeners to call each time we transition to a new state.
  final List<TransitionListener> onTransitionListeners;

  /// searches the entire tree of [StateDefinition] looking for a matching
  /// state.
  StateDefinition findStateDefinition(Type runtimeType) =>
      stateDefinitions[runtimeType];

  /// Checks if the given [stateType] is a top level state.
  bool isTopLevelState(Type stateType) {
    for (final sd in topStateDefinitions) {
      if (sd.stateType == stateType) return true;
    }
    return false;
  }

  StateDefinition findStateDefinitionFromString(String stateTypeName) {
    for (final state in stateDefinitions.values) {
      if (state.stateType.toString() == stateTypeName) {
        return state;
      }
    }
    return null;
  }

  /// wire the top state definitions into the stateDefinition map
  /// and into the [VirtualRoot]
  static Map<Type, StateDefinition> _expandStateDefinitions(
      StateDefinition<VirtualRoot> virtualRoot,
      List<StateDefinition<State>> topStateDefinitions) {
    final definitions = <Type, StateDefinition>{};

    addStateDefinition(definitions, virtualRoot);

    for (final stateDefinition in topStateDefinitions) {
      addStateDefinition(definitions, stateDefinition);

      /// wire the top level states into the virtual root.
      virtualRoot.childStateDefinitions.add(stateDefinition);

      final nested = stateDefinition.nestedStateDefinitions;
      for (final nestedStateDefinition in nested) {
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
    final def = findStateDefinition(childState);
    assert(def != null);

    return def.parent?.stateType;
  }
}
