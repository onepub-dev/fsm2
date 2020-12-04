import 'graph.dart';
import 'definitions/state_definition.dart';
import 'types.dart';
import 'virtual_root.dart';

/// * Checks the state machine to ensure that leaf  every [State]
/// can be reached.
///
/// We do this by checking that each state has at
/// least one event that leads to that [State].
///
/// The [analyse] method will only work if all [State]
/// transitions are explicity declared. If you use any
/// dynamic transitions (where you have a function that
/// works out the transition) then the call to [analyse]
/// will fail.
///
/// * Checks that there are no duplicate states
///
/// * Checks that no transition exist to an abstract state.
///
/// * Checks that all transitions target a registered state.
///
/// The [analyse] method prints any problems it finds.
///
/// Returns [true] if all States are reachable.
bool analyse(Graph graph) {
  var allGood = true;
  var stateDefinitionMap =
      Map<Type, StateDefinition<State>>.from(graph.stateDefinitions);

  var remainingStateMap =
      Map<Type, StateDefinition<State>>.from(graph.stateDefinitions);

  /// always remove the virtual root as is never directly used.
  remainingStateMap.remove(VirtualRoot);
  stateDefinitionMap.remove(VirtualRoot);

  /// the initial state is alwasy reachable.
  remainingStateMap.remove(graph.initialState);

  /// Check each state is reachable
  for (var stateDefinition in stateDefinitionMap.values) {
    /// print('Found state: ${stateDefinition.stateType}');
    for (var transitionDefinition in stateDefinition.getTransitions()) {
      var targetStates = transitionDefinition.targetStates;
      for (var targetState in targetStates) {
        var targetDefinition = stateDefinitionMap[targetState];

        /// we have a target for an unregistered state.
        if (targetDefinition == null) {
          /// this will be reported later.
          continue;
        }
        remainingStateMap.remove(targetState);

        /// If the targetDefinition can be reached then the initial state can be reached.
        remainingStateMap.remove(targetDefinition.initialState);

        // if the stateDefinition can be reached so can all its parents.
        var parent = targetDefinition.parent;
        while (parent.stateType != VirtualRoot) {
          remainingStateMap.remove(parent.stateType);
          parent = parent.parent;
        }
      }
    }
  }

  if (remainingStateMap.isNotEmpty) {
    allGood = false;
    print('Error: The following States cannot be reached.');

    for (var state in remainingStateMap.values) {
      print('Error: State: ${state.stateType}');
    }
  }

  /// check for duplicate states.
  var seen = <Type>{};
  for (var stateDefinition in graph.stateDefinitions.values) {
    if (seen.contains(stateDefinition.stateType)) {
      allGood = false;
      print(
          'Error: Found duplicate state ${stateDefinition.stateType}. Each state MUST only appear once in the FSM.');
    }
  }

  /// Check that no transition points to an  invalid state.
  /// 1) the toState must be defined
  /// 2) the toState must be a leaf state
  for (var stateDefinition in stateDefinitionMap.values) {
    if (stateDefinition.stateType == VirtualRoot) continue;
    // print('Found state: ${stateDefinition.stateType}');
    for (var transitionDefinition
        in stateDefinition.getTransitions(includeInherited: false)) {
      var targetStates = transitionDefinition.targetStates;
      for (var targetState in targetStates) {
        // Ignore our special terminal state.
        if (targetState == FinalState) continue;
        var toStateDefinition = graph.stateDefinitions[targetState];
        if (toStateDefinition == null) {
          allGood = false;
          print('Found transition to non-existant state ${targetState}.');
          continue;
        }

        // if (toStateDefinition.isAbstract) {
        //   allGood = false;
        //   print('Found transition to abstract state ${targetState}. Only leaf states may be the target of a transition');
        // }
      }
    }
  }

  /// check that all [coregion]s have at least two children
  for (var stateDefinition in stateDefinitionMap.values) {
    if (stateDefinition.isCoRegion) {
      if (stateDefinition.childStateDefinitions.isEmpty) {
        allGood = false;
        print(
            'Found coregion ${stateDefinition.stateType} which has no children.');
      }

      if (stateDefinition.childStateDefinitions.length == 1) {
        allGood = false;
        print(
            'Found coregion ${stateDefinition.stateType} which has a single child. CoRegions must have at least two chilren.');
      }
    }
  }

  /// Check that all child joins of a coregion target the same external state
  /// and that they only target states that are external to the coregion
  // TODO:

  /// InitialStates MUST target a child state (i.e. they can't target a grand children)
  for (var stateDefinition in stateDefinitionMap.values) {
    if (stateDefinition.initialState == null) continue;
    if (!stateDefinition.isChild(stateDefinition.initialState)) {
      allGood = false;
      print(
          'The initialState for ${stateDefinition.stateType} must target a child. ${stateDefinition.initialState} is not a child.');
    }
  }

  return allGood;
}
