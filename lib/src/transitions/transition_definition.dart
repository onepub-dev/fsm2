import 'dart:developer';
import 'dart:math' as math;

import 'package:fsm2/src/state_of_mind.dart';

import '../definitions/state_definition.dart';
import '../graph.dart';
import '../state_path.dart';
import '../types.dart';
import 'transition_notification.dart';

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
  final GuardCondition<E>? condition;

  /// An optional label used only on the exported diagrams to given the [condition]
  /// a descriptive label.  @See [label]
  final String? conditionLabel;

  /// The [SideEffect] function to call when this choice is
  /// selected as the transition.
  final SideEffect<E>? sideEffect;

  /// An optional label used only on the exported diagrams to given the [sideEffect]
  /// a descriptive label.  @See [label]
  final String? sideEffectLabel;

  /// list of the target states the will be transitioned into.
  List<Type> get targetStates;

  /// The list of events that this transition will trigger on.
  /// Whether the events are and/or'ed together is an
  /// implementation detail of the [TransitionDefinition] implementation.
  List<Type> get triggerEvents;

  TransitionDefinition(this.fromStateDefinition,
      {this.condition,
      this.sideEffect,
      this.conditionLabel,
      this.sideEffectLabel});

  ///
  /// Returns a transition label for use on exported diagrams. The
  /// label takes the standard UML2 form of:
  /// ```
  /// transition[condition]/sideeffect
  /// ```
  /// If the transition supports multiple events we just take use
  /// the first one.
  ///
  String get label => labelForEvent(triggerEvents[0]);

  ///
  /// Returns a transition label for use on exported diagrams. The
  /// label takes the standard UML2 form of:
  /// ```
  /// transition[condition]/sideeffect
  /// ```
  ///
  String labelForEvent(Type event) {
    final buf = StringBuffer();

    buf.write(event.toString());

    if (conditionLabel != null) {
      buf.write(' [$conditionLabel]');
    }
    if (sideEffectLabel != null) {
      buf.write('/$sideEffectLabel');
    }
    return buf.toString();
  }

  ///
  /// Applies [transition] to the  current statemachine and returns the resulting
  /// [StateOfMind].
  ///
  /// As the statemachine can be in multiple states the [stateOfMind] argument indicates what
  /// [stateOfMind] the [transition] is to be processed againts.
  /// /
  Future<StateOfMind> trigger(Graph graph, StateOfMind stateOfMind,
      TransitionNotification<E> transition) async {
    final exitPaths = <PartialStatePath>[];
    final enterPaths = <PartialStatePath>[];

    //for (final targetState in targetStates) {
    final fromPath = StatePath.fromLeaf(graph, transition.from!.stateType);
    final toPath = StatePath.fromLeaf(graph, transition.to!.stateType);

    final commonAncestor = findCommonAncestor(graph, fromPath, toPath);

    if (!transition.skipExit) {
      exitPaths.add(_getExitPaths(fromPath, commonAncestor));
    }

    if (!transition.skipEnter) {
      enterPaths.add(_getEnterPaths(toPath, commonAncestor));
    }

    final exitStates = dedupPaths(exitPaths);
    final enterStates = dedupPaths(enterPaths);

    final fromStateDefinition =
        graph.stateDefinitions[transition.from.runtimeType];
    await _callOnExits(fromStateDefinition, transition.event, exitStates);

    await _callSideEffect(transition);

    // when entering we must start from the root and work
    // towards the leaf.
    await _callOnEnters(enterStates.reversed.toList(), transition.event);

    for (final statePath in exitPaths.toSet()) {
      /// check that a transition occured
      if (statePath.isNotEmpty) {
        removePath(stateOfMind, statePath.fullPath(graph));
      }
    }

    for (final statePath in enterPaths.toSet()) {
      /// check that a transition occured
      if (statePath.isNotEmpty) {
        addPath(stateOfMind, statePath.fullPath(graph));
      }
    }

    // If we transitioned up to a parent [toPath]
    // then we will have removed the child (and all its parents) so
    // we need re-add the parent [toPath].
    // No need to call onEnter as we were already in the parent state.
    if (toPath.leaf == commonAncestor) {
      addPath(stateOfMind, toPath);
    }

    /// If we transition from a child to a parent then we need to remove the parent
    /// No need to run onExit as we are still in the parent state due to the child.
    stateOfMind.stripRedundantParents();

    log('Updated stateOfMind: $stateOfMind');

    return stateOfMind;
  }

  ///
  /// Used by onJoin and the likes to suppress a trigger if not all pre-conditions have been met.
  ///
  bool canTrigger(E event) => true;

  ///
  ///
  PartialStatePath _getExitPaths(
      StatePath fromAncestors, StateDefinition? commonAncestor) {
    final exitTargets = PartialStatePath();

    for (final fromAncestor in fromAncestors.path) {
      if (fromAncestor.stateType == commonAncestor!.stateType) {
        break;
      }

      exitTargets.addAncestor(fromAncestor);
    }
    return exitTargets;
  }

  ///
  ///
  PartialStatePath _getEnterPaths(
      StatePath toAncestors, StateDefinition? commonAncestor) {
    final enterTargets = PartialStatePath();

    for (final toAncestor in toAncestors.path) {
      if (toAncestor.stateType == commonAncestor!.stateType) break;

      enterTargets.addAncestor(toAncestor);
    }
    return enterTargets;
  }

  /// Walks up the tree looking for an ancestor that is common
  /// to the [fromAncestors] and [toAncestors] paths.
  ///
  /// If no common ancestor is found then null is returned;
  StateDefinition? findCommonAncestor(
      Graph graph, StatePath fromAncestors, StatePath toAncestors) {
    final toAncestorSet = toAncestors.path.toSet();

    for (final ancestor in fromAncestors.path) {
      if (toAncestorSet.contains(ancestor)) return ancestor;
    }
    return null;
  }

  ///
  /// When exiting a state we have to exit all ancestor states and
  /// active concurrent states.
  /// To do this we walk up the tree (towards the root) and call onExit
  /// for each ancestor up to but not including the common
  /// ancestor of the state we are entering.
  ///
  Future<void> _callOnExits(StateDefinition? fromState, Event? event,
      List<StateDefinition> states) async {
    for (final fromState in states) {
      await onExit(fromState, fromState.stateType, event);
    }
  }

  ///
  ///When entering a state we have to enter all ancestor states and
  /// including concurrent states.
  /// To do this we walk down the tree (from the root) and call onEnter
  /// for each ancestor starting from but not including the common
  /// ancestor of the state we are exiting.
  ///
  /// Can you join a concurrent state
  ///
  Future<void> _callOnEnters(List<StateDefinition> paths, Event? event) async {
    for (final toStateDefinition in paths) {
      await onEnter(toStateDefinition, toStateDefinition.stateType, event);
    }
  }

  ///
  /// Takes a list of [PartialStatePath]s and returns an ordered list
  /// of states from the leaf on the longest branch.
  /// It is expected that the partial paths are all relative to a common
  /// ancestor.
  /// We also dedup the States as we build the path.
  ///
  List<StateDefinition> dedupPaths(List<PartialStatePath> paths) {
    final maxLength = paths.fold<int>(
        0, (longest, element) => math.max(longest, element.path.length));

    final seenPaths = <StateDefinition>{};
    final orderedPaths = <StateDefinition>[];
    for (var i = 0; i < maxLength; i++) {
      for (final statePath in paths) {
        /// Only take if the path is long enough
        if (statePath.path.length >= (maxLength - i)) {
          final ofInterest =
              statePath.path[i - (maxLength - statePath.path.length)];
          if (!seenPaths.contains(ofInterest)) orderedPaths.add(ofInterest);
          seenPaths.add(ofInterest);
        }
      }
    }
    return orderedPaths;
  }

  ///
  /// list of transitions that this definition will cause when triggered.
  ///
  List<TransitionNotification> transitions(
      Graph graph, StateDefinition? from, Event event);

  Future<void> _callSideEffect(TransitionNotification<E> transition) async {
    if (sideEffect != null) {
      try {
        log('FSM calling sideEffect due to ${transition.event} ');
        await sideEffect!(transition.event);
        log('FSM completed sideEffect due to ${transition.event} ');
      } catch (e) {
        log('FSM sideEffect  due to ${transition.event} threw $e');
        rethrow;
      }
    }
  }
}
