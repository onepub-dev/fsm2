import 'dart:developer';

import 'graph.dart';
import 'state_definition.dart';
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
/// The [analyse] method logs any problems it finds.
///
/// Returns [true] if all States are reachable.
bool analyse(Graph graph) {
  var allGood = true;
  var stateDefinitionMap =
      Map<Type, StateDefinition<State>>.from(graph.stateDefinitions);

  var remainingStateMap =
      Map<Type, StateDefinition<State>>.from(graph.stateDefinitions);

  remainingStateMap.remove(graph.initialState);

  /// Check each state is reachable
  for (var stateDefinition in stateDefinitionMap.values) {
    if (stateDefinition.stateType != VirtualRoot) {
      /// If the parent can be reached then the initial state can be reached.
      remainingStateMap.remove(stateDefinition.initialState);

      /// log('Found state: ${stateDefinition.stateType}');
      for (var transitionDefinition in stateDefinition.getTransitions()) {
        var targetStates = transitionDefinition.targetStates;
        for (var targetState in targetStates) {
          remainingStateMap.remove(targetState);
        }
      }
    }

    /// abstract states cannot be transitioned to, so remove them
    /// as we go.
    if (stateDefinition.isAbstract) {
      remainingStateMap.remove(stateDefinition.stateType);
    }
  }

  if (remainingStateMap.isNotEmpty) {
    allGood = false;
    log('Error: The following States cannot be reached.');

    for (var state in remainingStateMap.values) {
      log('Error: State: ${state.stateType}');
    }
  }

  /// check for duplicate states.
  var seen = <Type>{};
  for (var stateDefinition in graph.stateDefinitions.values) {
    if (seen.contains(stateDefinition.stateType)) {
      allGood = false;
      log('Error: Found duplicate state ${stateDefinition.stateType}. Each state MUST only appear once in the FSM.');
    }
  }

  /// Check that no transition points to an  invalid state.
  /// 1) the toState must be defined
  /// 2) the toState must be a leaf state
  for (var stateDefinition in stateDefinitionMap.values) {
    if (stateDefinition.stateType == VirtualRoot) continue;
    // log('Found state: ${stateDefinition.stateType}');
    for (var transitionDefinition
        in stateDefinition.getTransitions(includeInherited: false)) {
      var targetStates = transitionDefinition.targetStates;
      for (var targetState in targetStates) {
        // Ignore our special terminal state.
        if (targetState == FinalState) continue;
        var toStateDefinition = graph.stateDefinitions[targetState];
        if (toStateDefinition == null) {
          allGood = false;
          log('Found transition to non-existant state ${targetState}.');
          continue;
        }

        // if (toStateDefinition.isAbstract) {
        //   allGood = false;
        //   log('Found transition to abstract state ${targetState}. Only leaf states may be the target of a transition');
        // }
      }
    }

    /// check that all [coregion]s have at least two children
    for (var stateDefinition in stateDefinitionMap.values) {
      if (stateDefinition.isCoRegion) {
        if (stateDefinition.childStateDefinitions.isEmpty) {
          allGood = false;
          log('Found coregion ${stateDefinition.stateType} which has no children.');
        }

        if (stateDefinition.childStateDefinitions.length == 1) {
          allGood = false;
          log('Found coregion ${stateDefinition.stateType} which has a single child. CoRegions must have at least two chilren.');
        }
      }
    }

    /// Check that all child joins of a coregion target the same external state
    /// and that they only target states that are external to the coregion
    // TODO:

    /// InitialStates MUST target a child state (i.e. they can't target a grand children)
    for (var stateDefinition in stateDefinitionMap.values) {
      if (stateDefinition.isCoRegion) {
        if (stateDefinition.childStateDefinitions.isEmpty) {
          allGood = false;
          log('Found coregion ${stateDefinition.stateType} which has no children.');
        }

        if (stateDefinition.childStateDefinitions.length == 1) {
          allGood = false;
          log('Found coregion ${stateDefinition.stateType} which has a single child. CoRegions must have at least two chilren.');
        }
      }
    }
  }

  return allGood;
}
