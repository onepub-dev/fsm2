import 'package:fsm/src/transition.dart';

class Graph<STATE, EVENT, SIDE_EFFECT> {
  Graph(this.initialState, this.stateDefinitions, this.onTransitionListeners);

  final STATE initialState;
  final Map<Type, State<STATE, EVENT, SIDE_EFFECT>> stateDefinitions;
  final List<TransitionListener<STATE, EVENT, SIDE_EFFECT>>
      onTransitionListeners;
}

class State<STATE, EVENT, SIDE_EFFECT> {
  State._();

  final Map<Type, TransitionTo<STATE, SIDE_EFFECT> Function(STATE, EVENT)>
      transitions = {};
}

class TransitionTo<STATE, SIDE_EFFECT> {
  TransitionTo(this.toState, [this.sideEffect]);

  final STATE toState;
  final SIDE_EFFECT sideEffect;
}

class GraphBuilder<STATE, EVENT, SIDE_EFFECT> {
  STATE _initialState;
  final Map<Type, State<STATE, EVENT, SIDE_EFFECT>> _stateDefinitions = {};
  final List<TransitionListener<STATE, EVENT, SIDE_EFFECT>>
      _onTransitionListeners = [];

  void initialState(STATE state) => _initialState = state;

  void state<S extends STATE>(
      BuildState<STATE, EVENT, SIDE_EFFECT> buildState) {
    final builder = StateBuilder<STATE, EVENT, SIDE_EFFECT>();
    buildState(builder);
    final definition = builder.build();
    _stateDefinitions[S] = definition;
  }

  void onTransition(TransitionListener<STATE, EVENT, SIDE_EFFECT> listener) =>
      _onTransitionListeners.add(listener);

  Graph<STATE, EVENT, SIDE_EFFECT> build() =>
      Graph(_initialState, _stateDefinitions, _onTransitionListeners);
}

class StateBuilder<STATE, EVENT, SIDE_EFFECT> {
  final State<STATE, EVENT, SIDE_EFFECT> _stateDefinition = State._();

  void on<E extends EVENT>(
      CreateTransitionTo<STATE, EVENT, SIDE_EFFECT> createTransitionTo) {
    _stateDefinition.transitions[E] = createTransitionTo;
  }

  TransitionTo<STATE, SIDE_EFFECT> transitionTo(
    STATE toState, [
    SIDE_EFFECT sideEffect,
  ]) =>
      TransitionTo(toState, sideEffect);

  State<STATE, EVENT, SIDE_EFFECT> build() => _stateDefinition;
}

typedef CreateTransitionTo<STATE, EVENT, SIDE_EFFECT>
    = TransitionTo<STATE, SIDE_EFFECT> Function(STATE s, EVENT e);

typedef BuildState<STATE, EVENT, SIDE_EFFECT> = Function(
    StateBuilder<STATE, EVENT, SIDE_EFFECT>);

typedef BuildGraph<STATE, EVENT, SIDE_EFFECT> = void Function(
    GraphBuilder<STATE, EVENT, SIDE_EFFECT>);

typedef TransitionListener<STATE, EVENT, SIDE_EFFECT> = void Function(
    Transition<STATE, EVENT, SIDE_EFFECT>);
