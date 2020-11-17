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

  // StateDefinition<S> _currentNestedStateDefinition;
  // State _currentNestedState;

  /// returns null if there are no transitions for the
  /// passed event out of the current state.
  Future<TransitionDefinition> _getTransition<E extends Event>(Type state, E event) async {
    var eventChoices = transitions[event.runtimeType];

    if (eventChoices == null) {
      return null;
    }

    return eventChoices.getTransition(state, this, event);
  }

  /// callback used when we enter this [State].
  /// Provide provide a default no-op implementation.
  OnEnter onEnter = (Type toState, Event event) {};

  /// callback used when we exiting this [State].
  /// Provide provide a default no-op implementation.
  OnExit onExit = (Type fromState, Event event) {};

  /// recursively searches for a state that can handle [event].
  /// We start from the leaves of the nested state tree working
  /// back to the root.
  // TransitionDefinition findTransition(State fromState, Event event) {
  //   TransitionDefinition transitionDefinition;

  //   if (_currentNestedStateDefinition != null) {
  //     transitionDefinition = _currentNestedStateDefinition._getTransition(_currentNestedState, event);
  //   }

  //   /// if a sub state doesn't process the event then we will try to.
  //   transitionDefinition ??= _getTransition(fromState, event);
  //   return transitionDefinition;
  // }

  /// Find the [TransitionDefinition] for the given [fromState] and [event].
  /// That is, find a transition for [event] that comes from [fromState].
  ///
  /// If the [event] isn't attached to [fromState] then null is returned.
  Future<TransitionDefinition> findTransition<E extends Event>(Type fromState, E event) async {
    TransitionDefinition transitionDefinition;
    for (var stateDefinition in _nestedStateDefinitions.values) {
      transitionDefinition = await stateDefinition.findTransition(fromState, event);

      if (transitionDefinition != null) break;
    }

    transitionDefinition ??= await _getTransition(fromState, event);

    return transitionDefinition;
  }

  List<TransitionDefinition> getStaticTransitions() {
    var transitionDefinitions = <TransitionDefinition>[];

    for (var choices in transitions.values) {
      for (var choice in choices.eventChoices) {
        var definition = ValidTransitionDefinition(
            S, this, choices.eventType, createTransition(choice.toState, sideEffect: choice.sideEffect));

        transitionDefinitions.add(definition);
      }
    }

    return transitionDefinitions;
  }

  Future<List<TransitionDefinition>> getStaticTransitionsForEvent(Type fromState, Event event) async {
    TransitionDefinition transitionDefinition;
    for (var stateDefinition in _nestedStateDefinitions.values) {
      transitionDefinition = await stateDefinition.findTransition(fromState, event);

      if (transitionDefinition != null) break;
    }

    for (var choices in transitions.values) {
      for (var choice in choices.eventChoices) {
        if (choice.toState != null) {}
      }
    }

    transitionDefinition ??= await _getTransition(fromState, event);

    return [transitionDefinition];
  }

  /// Adds a child state to this state definition.
  void addNestedState<C extends State>(BuildState<C> buildState) {
    final builder = StateBuilder<C>(C);
    buildState(builder);
    final definition = builder.build();
    definition.parent = this;
    _nestedStateDefinitions[C] = definition;
  }

  /// Adds a child co-state to this state defintion.
  /// A state may have any number of costates.
  /// All co-states simultaneously have a state
  /// This allows
  void addCoState(buildState) {}

  /// recursively searches through the list of nested [StateDefinitions]
  /// for a [StateDefinition] of type [runtimeType];
  StateDefinition<State> findStateDefintion(Type runtimeType) {
    StateDefinition found;
    for (var stateDefinition in _nestedStateDefinitions.values) {
      if (stateDefinition.stateType == runtimeType) {
        found = stateDefinition;
        break;
      } else {
        found = stateDefinition.findStateDefintion(runtimeType);
        if (found != null) break;
      }
    }
    return found;
  }

  List<StateDefinition> nestedStateDefinitions() {
    var definitions = <StateDefinition>[];

    if (_nestedStateDefinitions.isEmpty) return definitions;

    for (var stateDefinition in _nestedStateDefinitions.values) {
      definitions.add(stateDefinition);

      var nested = stateDefinition.nestedStateDefinitions();
      definitions.addAll(nested);
    }
    return definitions;
  }
}
