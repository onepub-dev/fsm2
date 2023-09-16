import 'dart:developer';

import 'package:meta/meta.dart';

import '../builders/co_region_builder.dart';
import '../builders/state_builder.dart';
import '../exceptions.dart';
import '../state_path.dart';
import '../transitions/noop_transition.dart';
import '../transitions/transition_definition.dart';
import '../types.dart';
import '../virtual_root.dart';
import 'co_region_definition.dart';

/// A [StateDefinition] represents a state defined in the statemachine builder.
class StateDefinition<S extends State> {
  StateDefinition(this.stateType);

  /// Optional label used when visualising the FSM.
  String? onEnterLabel;

  /// Optional label used when visualising the FSM.
  String? onExitLabel;

  /// The initial state if this is the parent of a nested set of states.
  Type? initialState;

  /// If true then this state and all child states
  /// will be printed on a separate page.
  bool pageBreak = false;

  /// If this is a nested state the [parent]
  /// is a link to the parent of this state.
  /// If this is not a nested state then parent will be null.
  StateDefinition? _parent;

  /// The parent of this state in the FSM tree.
  StateDefinition? get parent => _parent;

  /// The Type of the [State] that this [StateDefinition] is for.
  final Type stateType;

  /// The maps the set of [TransitionDefinition]s for a given [Event]
  /// for this [State].
  /// [TransitionDefinition] are defined via calls to [StateBuilder.on],
  ///  [StateBuilder.onFork] or [StateBuilder.onJoin]
  /// methods. There can be multiple transitions for each
  /// event due to the condition argument (which is a guard condition).
  ///
  /// There can also be multiple events that need to be mapped to a single
  /// [TransitionDefinition] in which case the [TransitionDefinition] will
  /// be in this map twice.
  final Map<Type, List<TransitionDefinition>> _eventTranstionsMap = {};

  /// List of State definitions for the set of immediate children of this state.
  /// The are in the same order as the builder declares them.
  final List<StateDefinition> childStateDefinitions = [];

  bool get isVirtualRoot => stateType == VirtualRoot;

  // ignore: use_setters_to_change_properties
  void setParent<P extends State>(StateDefinition<P> parent) {
    // log('set parent = ${parent.stateType} on ${stateType} ${hashCode}');
    _parent = parent;
  }

  /// Returns a complete list of nested [StateDefinition]s below
  /// this state in the tree.
  /// i.e. every possible child/grandchild/... state.
  List<StateDefinition> get nestedStateDefinitions {
    final definitions = <StateDefinition>[];

    if (childStateDefinitions.isEmpty) {
      return definitions;
    }

    for (final stateDefinition in childStateDefinitions) {
      definitions.add(stateDefinition);

      final nested = stateDefinition.nestedStateDefinitions;
      definitions.addAll(nested);
    }
    return definitions;
  }

  Future<void> _onEnter(Type fromState, Event? event) async {
    try {
      log('FSM onEnter called for $stateType due to ${event.runtimeType}');
      await onEnter(fromState, event);
      log('FSM onEnter completed for $stateType due to ${event.runtimeType}');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log('FSM onEnter threw $e for $stateType due to ${event.runtimeType}');
      rethrow;
    }
  }

  /// callback used when we enter toState.
  /// Provides a default no-op implementation.
  // ignore: prefer_function_declarations_over_variables
  OnEnter onEnter = (toState, event) => null;

  /// This method is called when we exit this state to give the
  /// [StateDefinition] a chance to do any internal cleanup.
  /// If you must call [_onExit] so that we can call the user
  /// defined [onExit] method.
  @mustCallSuper
  Future<void> _onExit(Type fromState, Event? event) async {
    try {
      log('FSM onExit called for $stateType due to ${event.runtimeType}');
      await onExit(fromState, event);
      log('FSM onExit completed for $stateType due to ${event.runtimeType}');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log('FSM onExit threw $e for $stateType due to ${event.runtimeType}');
      rethrow;
    }
  }

  /// callback used when we exiting this [State].
  /// Provide provide a default no-op implementation.
  // ignore: prefer_function_declarations_over_variables
  OnExit onExit = (toState, event) => null;

  /// Returns the first transition that can be triggered for
  ///  the given [event] from the
  /// given [fromState].
  ///
  /// When considering each event we must evaulate the guard
  /// condition to determine if the
  /// transition is valid.
  ///
  /// If no triggerable [event] can be found for the [fromState]
  /// then a [NoOpTransitionDefinition] is returned
  /// indicating that no transition will occur under the current conditions.
  ///
  /// If no matching [event] can be found for the [fromState]
  /// then an [InvalidTransitionException] is thrown.
  ///
  /// When searching for an event we have to do a recursive
  /// search (starting at the [fromState])
  /// up the tree of nested states as any events on an ancestor [State]
  ///  also apply to the child [fromState].
  ///
  Future<TransitionDefinition?> findTriggerableTransition<E extends Event>(
      Type fromState, E event) async {
    TransitionDefinition transitionDefinition;

    if (!_hasTransition(fromState, event)) {
      return null;
    }

    /// does the current state definition have a transition
    ///  that will fire for the give event.
    transitionDefinition = await _evaluateTransitions(event);

    // If [fromState] doesn't have a transitionDefintion that can be triggered
    // then we search the parents.
    var parent = this.parent;
    while (transitionDefinition is NoOpTransitionDefinition &&
        parent!.stateType != VirtualRoot) {
      transitionDefinition = await parent._evaluateTransitions(event);
      // as FutureOr<NoOpTransitionDefinition<State, Event>>);
      parent = parent.parent;
    }

    return transitionDefinition;
  }

  /// returns a [NoOpTransitionDefinition] if none of
  /// the transitions would be triggered
  /// or if there where no transitions for [event].
  Future<TransitionDefinition> _evaluateTransitions<E extends Event>(
      E event) async {
    final transitionChoices = _eventTranstionsMap[event.runtimeType]
        as List<TransitionDefinition<E>>?;

    if (transitionChoices == null) {
      return NoOpTransitionDefinition<S, E>(this, E);
    }

    return _evaluateConditions(transitionChoices, event);
  }

  /// Evaluates each guard condition for the given [event]
  ///
  /// Conditions are applied to determine which transition occurs.
  ///
  /// If no condition allows the transition to fire then we return
  /// a [NoOpTransitionDefinition] which result in no state transition occuring.
  ///
  Future<TransitionDefinition<E>> _evaluateConditions<E extends Event>(
      List<TransitionDefinition<E>> transitionChoices, E event) async {
    assert(transitionChoices.isNotEmpty, 'choices cannot be empty');
    for (final transitionDefinition in transitionChoices) {
      final td = transitionDefinition;

      final dtd = td as dynamic;
      final c = dtd.condition as dynamic;
      if (c.call(event) == true) {
        if (transitionDefinition.canTrigger(event)) {
          /// static transition
          return transitionDefinition;
        }
      }

      // // ignore: unnecessary_cast
      // if (td.condition(event as E)) {
      //   /// pseudo states such as onJoin may still not be able to trigger.
      //   if (transitionDefinition.canTrigger(event)) {
      //     /// static transition
      //     return transitionDefinition;
      //   }
      // }
    }
    return NoOpTransitionDefinition<S, E>(this, E);
  }

  /// A state is a terminal state if it has no transitions and
  /// therefore we can never leave this state.
  /// We need to check any parent states as we inherit
  /// transitions from all our ancestors.
  bool get isTerminal => getTransitions().isEmpty;

  /// A state is a leaf state if it has no child states.
  bool get isLeaf => childStateDefinitions.isEmpty;

  /// A state is an abstract state if it has any child states
  /// You cannot use an abstract state as an transition target.
  bool get isAbstract =>
      childStateDefinitions.isNotEmpty || stateType == VirtualRoot;

  /// The state has concurrent children.
  bool get isCoRegion => this is CoRegionDefinition;

  /// Returns the set of transitions 'from' this state.
  /// As a state inherits any transitions defined by
  /// an ancestor this method also returns the transistions
  /// for all ancestors by default.
  ///
  /// The transitions are ordered from leaf to root.
  ///
  /// Set [includeInherited] to false to exclude inherited transitions.
  ///
  List<TransitionDefinition<Event>> getTransitions(
      {bool includeInherited = true}) {
    final transitionDefinitions = <TransitionDefinition<Event>>[];

    for (final transitions in _eventTranstionsMap.values) {
      transitionDefinitions.addAll(transitions);
    }

    /// add inherited transitions.
    if (includeInherited) {
      var parent = this.parent!;
      while (parent.stateType != VirtualRoot) {
        transitionDefinitions.addAll(parent.getTransitions());

        parent = parent.parent!;
      }
    }
    return transitionDefinitions;
  }

  void addTransition<E extends Event>(
      TransitionDefinition<E> transitionDefinition) {
    var transitionDefinitions = _eventTranstionsMap[E];
    transitionDefinitions ??= <TransitionDefinition<E>>[];

    if (transitionDefinition.condition == noopGuardCondition) {
      _validateHasNoNoopConditions(E);
    }

    transitionDefinitions.add(transitionDefinition);
    _eventTranstionsMap[E] = transitionDefinitions;
  }

  /// Adds a child state to this state definition.
  void _addNestedState<C extends State>(
    BuildState<C> buildState,
  ) {
    final builder = StateBuilder<C>(this, StateDefinition(C));
    //builder.parent = this;
    buildState(builder);
    final definition = builder.build()..setParent(this);
    childStateDefinitions.add(definition);
  }

  /// Adds a child [CoRegionDefinition] to this state defintion.
  /// A state may have any number of coregions.
  /// All coregions simultaneously have a state
  /// This allows
  void _addCoRegion<CO extends State>(BuildCoRegion<CO> buildState) {
    final builder = CoRegionBuilder<CO>(this, CoRegionDefinition(CO));
    //  builder.parent = this;
    buildState(builder);
    final definition = builder.build()..setParent(this);
    childStateDefinitions.add(definition);
  }

  /// recursively searches through the list of nested [StateDefinition]s
  /// for a [StateDefinition] of type [stateDefinitionType];
  StateDefinition<State>? findStateDefintion(Type? stateDefinitionType,
      {bool includeChildren = true}) {
    StateDefinition? found;
    for (final stateDefinition in childStateDefinitions) {
      if (stateDefinition.stateType == stateDefinitionType) {
        found = stateDefinition;
        break;
      } else {
        if (includeChildren) {
          found = stateDefinition.findStateDefintion(stateDefinitionType);
          if (found != null) {
            break;
          }
        }
      }
    }
    return found;
  }

  /// Checks that the [fromState] has a transition for [event].
  ///
  /// We search up the tree of nested states starting at [fromState]
  /// as any transitions on parent states can also be applied
  ///
  bool _hasTransition<E extends Event>(Type fromState, E event) {
    final transitions = getTransitions();
    // var transitions = _eventTranstionsMap[event.runtimeType];

    if (transitions.isEmpty) {
      return false;
    }

    /// Do we have a transtion for [event]
    return transitions.fold<bool>(
        false,
        (found, transition) =>
            found || transition.triggerEvents.contains(event.runtimeType));
  }

  void _validateHasNoNoopConditions(Type eventType) {
    if (_eventTranstionsMap[eventType] == null) {
      return;
    }
    for (final transitionDefinition in _eventTranstionsMap[eventType]!) {
      // darts generic typedefs are broken for inheritence
      // final a = transitionDefinition;

      final dtd = transitionDefinition as dynamic;
      // ignore: avoid_dynamic_calls
      final c = dtd.condition as dynamic;

      if (c == noopGuardCondition) {
        throw NullConditionMustBeLastException(eventType);
      }

      // c.call(qe.event);

      // if (a.condition == noopGuardCondition) {
      //   throw NullConditionMustBeLastException(eventType);
      // }
    }
  }

  StatePath get statePath {
    final path = <StateDefinition>[];

    StateDefinition? parent = this;
    while (parent != null) {
      path.add(parent);
      parent = parent.parent;
    }

    return StatePath(path);
  }

  /// Returns true if the given [state] is a direct child
  /// of this [StateDefinition].
  bool isDirectChild(Type state) =>
      childStateDefinitions.map((sd) => sd.stateType).contains(state);

  /// Returns true if we are a descendant of [potentialAncestor]
  bool isDecendentOf(StatePath potentialAncestor) {
    StateDefinition? parent = this;

    while (parent != null) {
      if (parent == potentialAncestor.leaf) {
        return true;
      }
      parent = parent.parent;
    }

    return false;
  }

  /// default implementation.
  bool canTrigger(Type event) => true;
}

/// used to hide internal api
Future<void> onEnter(StateDefinition sd, Type toState, Event? event) async {
  await sd._onEnter(toState, event);
}

Future<void> onExit(StateDefinition sd, Type fromState, Event? event) async {
  await sd._onExit(fromState, event);
}

void addCoRegion<CO extends State>(
    StateDefinition sd, BuildCoRegion<CO> buildState) {
  sd._addCoRegion(buildState);
}

void addNestedState<C extends State>(
  StateDefinition sd,
  BuildState<C> buildState,
) {
  sd._addNestedState(buildState);
}
