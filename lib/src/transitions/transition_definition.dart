import 'dart:math';

import 'package:fsm2/src/state_of_mind.dart';

import '../graph.dart';
import '../definitions/state_definition.dart';
import '../state_path.dart';
import '../types.dart';

/// Defines FSM transition: the change from one state to another.
abstract class TransitionDefinition< // S extends State,
    E extends Event> {
  /// The state this transition is attached to.
  final StateDefinition<State> fromStateDefinition;

  /// The condition that must be met for this [TransitionDefinition] to be triggered.
  /// If [condition] is null then it always evaluates to true and the
  /// event will be triggered. Null conditions are always the last [condition]
  /// to be evaulated against an event, so any other [condition] that returns true
  /// will be fired in preference to a null [condition].
  final GuardCondition<E> condition;

  /// The [SideEffect] function to call when this choice is
  /// selected as the transition.
  final SideEffect sideEffect;

  /// list of the target states the will be transitioned into.
  List<Type> get targetStates;

  /// The list of events that this transition will trigger on.
  /// Whether the events are and/or'ed together is an
  /// implementation detail of the [Transition] implementation.
  List<Type> get triggerEvents;

  TransitionDefinition(this.fromStateDefinition, {this.condition, this.sideEffect});

  /// Applies [event] to the  current statemachine and returns the resulting
  /// [StateOfMind].
  ///
  /// As the statemachine can be in multiple states the [state] argument indicates what
  /// [State] the [event] is to be processed againts.
  Future<StateOfMind> trigger(Graph graph, StateOfMind stateOfMind, Type fromState, Event event) async {
    var exitPaths = <PartialStatePath>[];
    var enterPaths = <PartialStatePath>[];

    for (var targetState in targetStates) {
      var toStateDefinition = graph.stateDefinitions[targetState];

      var fromPath = StatePath.fromLeaf(graph, fromState);
      var toPath = StatePath.fromLeaf(graph, toStateDefinition.stateType);

      var commonAncestor = findCommonAncestor(graph, fromPath, toPath);

      exitPaths.add(getExitPath(fromPath, commonAncestor));
      enterPaths.add(getEnterPath(toPath, commonAncestor));
    }

    var exitPath = dedupPaths(exitPaths);
    var enterPath = dedupPaths(enterPaths);

    var fromStateDefinition = graph.stateDefinitions[fromState];
    callOnExits(fromStateDefinition, event, exitPath);

    if (sideEffect != null) await sideEffect();

    // when entering we must start from the root and work
    // towards the leaf.
    callOnEnters(enterPath.reversed.toList(), event);

    for (var statePath in exitPaths.toSet()) {
      /// check that a transition occured
      if (statePath.isNotEmpty) {
        stateOfMind.removePath(statePath.fullPath(graph));
      }
    }

    for (var statePath in enterPaths.toSet()) {
      /// check that a transition occured
      if (statePath.isNotEmpty) {
        stateOfMind.addPath(statePath.fullPath(graph));
      }
    }

    return stateOfMind;
  }

  PartialStatePath getExitPath(StatePath fromAncestors, StateDefinition commonAncestor) {
    var exitTargets = PartialStatePath();

    for (var fromAncestor in fromAncestors.path) {
      if (fromAncestor.stateType == commonAncestor.stateType) break;

      exitTargets.addAncestor(fromAncestor);
    }
    return exitTargets;
  }

  PartialStatePath getEnterPath(StatePath toAncestors, StateDefinition commonAncestor) {
    var enterTargets = PartialStatePath();

    for (var toAncestor in toAncestors.path) {
      if (toAncestor.stateType == commonAncestor.stateType) break;

      enterTargets.addAncestor(toAncestor);
    }
    return enterTargets;
  }

  /// Walks up the tree looking for an ancestor that is common
  /// to the [fromState] and [targetStates]
  ///
  /// If no common ancestor is found then null is returned;
  StateDefinition findCommonAncestor(Graph graph, StatePath fromAncestors, StatePath toAncestors) {
    var toAncestorSet = toAncestors.path.toSet();

    for (var ancestor in fromAncestors.path) {
      if (toAncestorSet.contains(ancestor)) return ancestor;
    }
    return null;
  }

  /// When exiting a state we have to exit all ancestor states and
  /// active concurrent states.
  /// To do this we walk up the tree (towards the root) and call onExit
  /// for each ancestor up to but not including the common
  /// ancestor of the state we are entering.
  void callOnExits(StateDefinition fromState, Event event, List<StateDefinition> states) async {
    for (var fromState in states) {
      if (fromState.onExit != null) {
        await fromState.onExit(fromState.stateType, event);
      }
    }
  }

  /// When entering a state we have to enter all ancestor states and
  /// including concurrent states.
  /// To do this we walk down the tree (from the root) and call onEnter
  /// for each ancestor starting from but not including the common
  /// ancestor of the state we are exiting.
  ///
  /// Can you join a concurrent state
  void callOnEnters(List<StateDefinition> paths, Event event) async {
    for (var toStateDefinition in paths) {
      if (toStateDefinition.onEnter != null) {
        await toStateDefinition.onEnter(toStateDefinition.stateType, event);
      }
    }
  }

  /// Takes a list of [PartialStatePath]s and returns an ordered list
  /// of states from the leaf on the longest branch.
  /// It is expected that the partial paths are all relative to a common
  /// ancestor.
  /// We also dedup the States as we build the path.
  List<StateDefinition> dedupPaths(List<PartialStatePath> paths) {
    var maxLength = paths.fold<int>(0, (longest, element) => max(longest, element.path.length));

    var seenPaths = <StateDefinition>{};
    var orderedPaths = <StateDefinition>[];
    for (var i = 0; i < maxLength; i++) {
      for (var statePath in paths) {
        /// Only take if the path is long enough
        if (statePath.path.length >= (maxLength - i)) {
          var ofInterest = statePath.path[i - (maxLength - statePath.path.length)];
          if (!seenPaths.contains(ofInterest)) orderedPaths.add(ofInterest);
          seenPaths.add(ofInterest);
        }
      }
    }
    return orderedPaths;
  }
}

// /// Valid transition meaning that machine goes from [fromState]
// /// to [targetStates]. Transition is caused by [event].
// ///
// /// It contains optional [sideEffect].
// class ValidTransitionDefinition extends TransitionDefinition {
//   ValidTransitionDefinition(Type fromState, StateDefinition fromStateDefinition, Type eventType,
//       List<Type> targetStates, SideEffect sideEffect)
//       : super._internal(fromState, fromStateDefinition, eventType, targetStates, sideEffect: sideEffect);
// }

// // /// Invalid transition called by [event]. Machine stays in [state].
// // class InvalidTransition extends Transition {
// //   InvalidTransition(this.fromState, this.event);

// //   final State fromState;
// //   final Event event;
// // }

// // /// This is an implicit transition which is added to any terminal State.
// // ///
// // /// A State is considered terminal if there are not transitions out of the
// // /// State.
// // class TerminalTransitionDefinition extends TransitionDefinition {
// //   /// no transition so [fromState] == [toState].
// //   TerminalTransitionDefinition(Type fromState, StateDefinition fromStateDefinition)
// //       : super._internal(fromState, fromStateDefinition, TerminalEvent, createTransition(TerminalState));
// //   @override
// //   Future<StateOfMind> trigger(Graph graph, StateOfMind stateOfMind, Type fromState, Event event) async {
// //     return Future.value(_transition);
// //   }
// // }
