import 'definitions/state_definition.dart';
import 'graph.dart';
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
/// Returns true if all States are reachable.
bool analyse(Graph graph) {
  var allGood = true;
  final stateDefinitionMap =
      Map<Type, StateDefinition<State>>.from(graph.stateDefinitions);

  final remainingStateMap =
      Map<Type, StateDefinition<State>>.from(graph.stateDefinitions)

        /// always remove the virtual root as is never directly used.
        ..remove(VirtualRoot);
  stateDefinitionMap.remove(VirtualRoot);

  /// the initial state is alwasy reachable.
  remainingStateMap.remove(graph.initialState);

  /// Check each state is reachable
  for (final stateDefinition in stateDefinitionMap.values) {
    /// print('Found state: ${stateDefinition.stateType}');
    for (final transitionDefinition in stateDefinition.getTransitions()) {
      final targetStates = transitionDefinition.targetStates;
      for (final targetState in targetStates) {
        final targetDefinition = stateDefinitionMap[targetState];

        /// we have a target for an unregistered state.
        if (targetDefinition == null) {
          /// this will be reported later.
          continue;
        }
        remainingStateMap
          ..remove(targetState)

          /// If the targetDefinition can be reached then the
          ///  initial state can be reached.
          ..remove(targetDefinition.initialState);

        // if the stateDefinition can be reached so can all its parents.
        var parent = targetDefinition.parent!;
        while (parent.stateType != VirtualRoot) {
          remainingStateMap.remove(parent.stateType);
          parent = parent.parent!;
        }
      }
    }
  }

  if (remainingStateMap.isNotEmpty) {
    allGood = false;
    // ignore: avoid_print
    print('Error: The following States cannot be reached.');

    for (final state in remainingStateMap.values) {
      // ignore: avoid_print
      print('Error: State: ${state.stateType}');
    }
  }

  /// check for duplicate states.
  final seen = <Type>{};
  for (final stateDefinition in graph.stateDefinitions.values) {
    if (seen.contains(stateDefinition.stateType)) {
      allGood = false;
      // ignore: avoid_print
      print(
          '''Error: Found duplicate state ${stateDefinition.stateType}. Each state MUST only appear once in the FSM.''');
    }
  }

  /// Check that no transition points to an  invalid state.
  /// 1) the toState must be defined
  /// 2) the toState must be a leaf state
  for (final stateDefinition in stateDefinitionMap.values) {
    if (stateDefinition.stateType == VirtualRoot) {
      continue;
    }
    // print('Found state: ${stateDefinition.stateType}');
    for (final transitionDefinition
        in stateDefinition.getTransitions(includeInherited: false)) {
      final targetStates = transitionDefinition.targetStates;
      for (final targetState in targetStates) {
        // Ignore our special terminal state.
        if (targetState == TerminalState) {
          continue;
        }
        final toStateDefinition = graph.stateDefinitions[targetState];
        if (toStateDefinition == null) {
          allGood = false;
          // ignore: avoid_print
          print('Found transition to non-existant state $targetState.');
          continue;
        }

        // if (toStateDefinition.isAbstract) {
        //   allGood = false;
        //   print('Found transition to abstract state ${targetState}.
        //Only leaf states may be the target of a transition');
        // }
      }
    }
  }

  /// check that all [coregion]s have at least two children
  for (final stateDefinition in stateDefinitionMap.values) {
    if (stateDefinition.isCoRegion) {
      if (stateDefinition.childStateDefinitions.isEmpty) {
        allGood = false;
        // ignore: avoid_print
        print(
            '''Found coregion ${stateDefinition.stateType} which has no children.''');
      }

      if (stateDefinition.childStateDefinitions.length == 1) {
        allGood = false;
        // ignore: avoid_print
        print(
            '''Found coregion ${stateDefinition.stateType} which has a single child. CoRegions must have at least two chilren.''');
      }
    }
  }

  /// Check that all child joins of a coregion target the same external state
  /// and that they only target states that are external to the coregion
  /// InitialStates MUST target a child state (i.e. they can't target 
  /// grand children)
  for (final stateDefinition in stateDefinitionMap.values) {
    if (stateDefinition.initialState == null) {
      continue;
    }
    if (!stateDefinition.isDirectChild(stateDefinition.initialState!)) {
      allGood = false;
      // ignore: avoid_print
      print(
          '''The initialState for ${stateDefinition.stateType} must target a child. ${stateDefinition.initialState} is not a child.''');
    }
  }

  return allGood;
}
