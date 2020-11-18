import 'package:fsm2/src/exceptions.dart';
import 'package:fsm2/src/state_builder.dart';

import 'transition.dart';

import 'event_choices.dart';
import 'transition_definition.dart';
import 'types.dart';

class StateDefinition<S extends State> {
  StateDefinition(this.stateType);

  /// If this is a nested state the [parent]
  /// is a link to the parent of this state.
  /// If this is not a nested state then parent will be null.
  StateDefinition parent;

  /// The Type of the [State] that this [StateDefinition] is for.
  final Type stateType;

  /// The maps the set of choices for a given [Event]
  /// for this [State].
  /// Choices are defined via calls to either [on] or [onDynamic]
  /// methods. There can be multiple transitions for each
  /// event due to the [condition] argument (which is a guard condition).
  final Map<Type, EventChoices> transitions = {};

  /// State definitions for a nested set of states.
  final Map<Type, StateDefinition> _nestedStateDefinitions = {};

  /// callback used when we enter this [State].
  /// Provide provide a default no-op implementation.
  OnEnter onEnter = (Type toState, Event event) {};

  /// callback used when we exiting this [State].
  /// Provide provide a default no-op implementation.
  OnExit onExit = (Type fromState, Event event) {};

  /// Returns the first transition that can be triggered for the given [event] from the
  /// given [fromState].
  ///
  /// When considering each event we must evaulate the guard condition to determine if the
  /// transition is valid.
  ///
  /// If no triggerable [event] can be found for the [fromState] then a [NoOpTranstionDefinition] is returned
  /// indicating that no transition will occur under the current conditions.
  ///
  /// If no matching [event] can be found for the [fromState] then an [InvalidTransitionException] is thrown.
  ///
  /// When searching for an event we have to do a recursive search (starting at the [fromState])
  /// up the tree of nested states as any events on an ancestor [State] also apply to the child [fromState].
  ///
  Future<TransitionDefinition> findTriggerableTransition<E extends Event>(Type fromState, E event) async {
    TransitionDefinition transitionDefinition;

    if (!hasTransition(fromState, event)) {
      throw InvalidTransitionException(fromState, event);
    }

    /// does the current state definition have a transition for the give event.
    transitionDefinition = await _evaluateTransitions(event);

    // If [fromState] doesn't have a transitionDefintion that can be triggered
    // then we search the parents.
    var parent = this.parent;
    while (transitionDefinition is NoOpTransitionDefinition && parent != null) {
      transitionDefinition = await parent._evaluateTransitions(event);
      parent = parent.parent;
    }

    return transitionDefinition;
  }

  /// returns a [NoOpTransitionDefinition] if none of the transitions would be triggered
  /// or if there where no transitions for [event].
  Future<TransitionDefinition> _evaluateTransitions<E extends Event>(E event) async {
    var eventChoices = transitions[event.runtimeType];

    if (eventChoices == null) return NoOpTransitionDefinition(stateType, this, E);

    return await eventChoices.evaluateConditions(stateType, this, event);
  }

  List<TransitionDefinition> getStaticTransitions() {
    var transitionDefinitions = <TransitionDefinition>[];
    if (transitions.isEmpty) {
      transitionDefinitions.add(TerminalTransitionDefinition(stateType, this));
      return transitionDefinitions;
    }

    for (var choices in transitions.values) {
      for (var choice in choices.eventChoices) {
        if (choice.isStatic) {
          var definition = ValidTransitionDefinition(
              S, this, choices.eventType, createTransition(choice.toState, sideEffect: choice.sideEffect));

          transitionDefinitions.add(definition);
        }
      }
    }

    return transitionDefinitions;
  }

  Future<List<TransitionDefinition>> getStaticTransitionsForEvent(Type fromState, Event event) async {
    TransitionDefinition transitionDefinition;
    for (var stateDefinition in _nestedStateDefinitions.values) {
      transitionDefinition = await stateDefinition.findTriggerableTransition(fromState, event);

      if (transitionDefinition != null) break;
    }

    for (var choices in transitions.values) {
      for (var choice in choices.eventChoices) {
        if (choice.toState != null) {}
      }
    }

    transitionDefinition ??= await _evaluateTransitions(event);

    return [transitionDefinition];
  }

  /// Adds a child state to this state definition.
  void addNestedState<C extends State>(BuildState<C> buildState) {
    final builder = StateBuilder<C>(C);
    buildState(builder);
    final definition = builder.build();
    definition.parent = this;
    _nestedStateDefinitions[C] = definition;

    /// validate that this is a valid state to add at this point in the tree
    var parent = definition.parent;
    while (parent != null) {
      if (parent.stateType == definition.stateType) {
        throw InvalidNestedStateException(definition, parent);
      }
      parent = parent.parent;
    }
  }

  /// Adds a child co-state to this state defintion.
  /// A state may have any number of costates.
  /// All co-states simultaneously have a state
  /// This allows
  void addCoState<CO extends State>(BuildState<CO> buildState) {
    //TODO: for the moment we hack a costat as a nested state.
    addNestedState(buildState);
  }

  /// recursively searches through the list of nested [StateDefinitions]
  /// for a [StateDefinition] of type [stateDefinitionType];
  StateDefinition<State> findStateDefintion(Type stateDefinitionType) {
    StateDefinition found;
    for (var stateDefinition in _nestedStateDefinitions.values) {
      if (stateDefinition.stateType == stateDefinitionType) {
        found = stateDefinition;
        break;
      } else {
        found = stateDefinition.findStateDefintion(stateDefinitionType);
        if (found != null) break;
      }
    }
    return found;
  }

  /// Returns a list of immediately nested [StateDefinition]s.
  /// i.e. we don't search child [StateDefinition]s for further
  /// nested [StateDefinition]s.
  List<StateDefinition> get nestedStateDefinitions {
    var definitions = <StateDefinition>[];

    if (_nestedStateDefinitions.isEmpty) return definitions;

    for (var stateDefinition in _nestedStateDefinitions.values) {
      definitions.add(stateDefinition);

      var nested = stateDefinition.nestedStateDefinitions;
      definitions.addAll(nested);
    }
    return definitions;
  }

  /// Checks that the [fromState] has a transition for [event].
  ///
  /// We search up the tree of nested states starting at [fromState]
  /// as any transitions on parent states can also be applied
  ///
  bool hasTransition<E extends Event>(Type fromState, E event) {
    for (var eventChoices in transitions.values) {
      if (eventChoices.eventType == event.runtimeType) {
        return true;
      }
    }

    // we didn't find one in the current [StateDefinition] so lets
    // search the parents.
    var parent = this.parent;
    while (parent != null) {
      for (var eventChoices in parent.transitions.values) {
        if (eventChoices.eventType == event.runtimeType) {
          return true;
        }
      }
      parent = parent.parent;
    }
    return false;
  }
}
