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

  VoidCallback<STATE> onEnter = (_) {};
  VoidCallback<STATE> onExit = (_) {};
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
    BuildState<S, STATE, EVENT, SIDE_EFFECT> buildState,
  ) {
    final builder = StateBuilder<S, STATE, EVENT, SIDE_EFFECT>();
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
class StateBuilder<S extends STATE, STATE, EVENT, SIDE_EFFECT> {
  final _State<STATE, EVENT, SIDE_EFFECT> _stateDefinition = _State();

  /// Sets transition that will be called when event of type [E]
  /// is sent to machine via [StateMachine.transition] method.
  void on<E extends EVENT>(
      CreateTransitionTo<S, STATE, E, EVENT, SIDE_EFFECT> createTransitionTo) {
    _stateDefinition.transitions[E] =
        (STATE s, EVENT e) => createTransitionTo(s, e);
  }

  /// Set callback that will be called right after machine enters this state.
  void onEnter(void Function(S) doOnEnter) {
    _stateDefinition.onEnter = (STATE s) => doOnEnter(s);
  }

  /// Set callback that will be called right before machine exits this state.
  void onExit(void Function(S) doOnEnter) {
    _stateDefinition.onExit = (STATE s) => doOnEnter(s);
  }

  /// Creates transition.
  TransitionTo<STATE, SIDE_EFFECT> transitionTo(
    STATE toState, [
    SIDE_EFFECT sideEffect,
  ]) =>
      TransitionTo._(toState, sideEffect);

  _State<STATE, EVENT, SIDE_EFFECT> build() => _stateDefinition;
}

typedef CreateTransitionTo<S extends STATE, STATE, E extends EVENT, EVENT,
        SIDE_EFFECT>
    = TransitionTo<STATE, SIDE_EFFECT> Function(S s, E e);

typedef BuildState<S extends STATE, STATE, EVENT, SIDE_EFFECT> = Function(
    StateBuilder<S, STATE, EVENT, SIDE_EFFECT>);

typedef BuildGraph<STATE, EVENT, SIDE_EFFECT> = void Function(
    GraphBuilder<STATE, EVENT, SIDE_EFFECT>);

typedef TransitionListener<STATE, EVENT, SIDE_EFFECT> = void Function(
    Transition<STATE, EVENT, SIDE_EFFECT>);

typedef VoidCallback<T> = void Function(T);
