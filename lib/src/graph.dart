part of 'state_machine.dart';

class Graph<STATE, EVENT, SIDE_EFFECT> {
  Graph(this.initialState, this.stateDefinitions, this.onTransitionListeners);

  final STATE initialState;
  final Map<Type, _State<STATE, EVENT, SIDE_EFFECT>> stateDefinitions;
  final List<TransitionListener<STATE, EVENT, SIDE_EFFECT>>
      onTransitionListeners;
}

class _State<STATE, EVENT, SIDE_EFFECT> {
  _State();

  final Map<Type, TransitionTo<STATE, SIDE_EFFECT> Function(STATE, EVENT)>
      transitions = {};
}

class TransitionTo<STATE, SIDE_EFFECT> {
  TransitionTo._(this.toState, [this.sideEffect]);

  final STATE toState;
  final SIDE_EFFECT sideEffect;
}

/// Builder for FSM.
///
/// Instance of this class is passed to [StateMachine.create] method.
class GraphBuilder<STATE, EVENT, SIDE_EFFECT> {
  STATE _initialState;
  final Map<Type, _State<STATE, EVENT, SIDE_EFFECT>> _stateDefinitions = {};
  final List<TransitionListener<STATE, EVENT, SIDE_EFFECT>>
      _onTransitionListeners = [];

  /// Sets initial state.
  void initialState(STATE state) => _initialState = state;

  /// Adds state definition.
  void state<S extends STATE>(
    BuildState<STATE, EVENT, SIDE_EFFECT> buildState,
  ) {
    final builder = StateBuilder<STATE, EVENT, SIDE_EFFECT>();
    buildState(builder);
    final definition = builder.build();
    _stateDefinitions[S] = definition;
  }

  /// Sets [listener] that will be called on each transition.
  void onTransition(TransitionListener<STATE, EVENT, SIDE_EFFECT> listener) =>
      _onTransitionListeners.add(listener);

  Graph<STATE, EVENT, SIDE_EFFECT> build() =>
      Graph(_initialState, _stateDefinitions, _onTransitionListeners);
}

/// State builder.
///
/// Instance of this class is passed to [GraphBuilder.state] method.
class StateBuilder<STATE, EVENT, SIDE_EFFECT> {
  final _State<STATE, EVENT, SIDE_EFFECT> _stateDefinition = _State();

  /// Sets transition that will be called when event of type [E]
  /// is sent to machine via [StateMachine.transition] method.
  void on<E extends EVENT>(
    CreateTransitionTo<STATE, EVENT, SIDE_EFFECT> createTransitionTo,
  ) {
    _stateDefinition.transitions[E] = createTransitionTo;
  }

  /// Creates transition.
  TransitionTo<STATE, SIDE_EFFECT> transitionTo(
    STATE toState, [
    SIDE_EFFECT sideEffect,
  ]) =>
      TransitionTo._(toState, sideEffect);

  _State<STATE, EVENT, SIDE_EFFECT> build() => _stateDefinition;
}

typedef CreateTransitionTo<STATE, EVENT, SIDE_EFFECT>
    = TransitionTo<STATE, SIDE_EFFECT> Function(STATE s, EVENT e);

typedef BuildState<STATE, EVENT, SIDE_EFFECT> = Function(
    StateBuilder<STATE, EVENT, SIDE_EFFECT>);

typedef BuildGraph<STATE, EVENT, SIDE_EFFECT> = void Function(
    GraphBuilder<STATE, EVENT, SIDE_EFFECT>);

typedef TransitionListener<STATE, EVENT, SIDE_EFFECT> = void Function(
    Transition<STATE, EVENT, SIDE_EFFECT>);
