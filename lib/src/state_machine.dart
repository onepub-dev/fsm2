import 'dart:async';

import 'package:dfunc/dfunc.dart';

part 'graph.dart';

part 'transition.dart';

/// Finite State Machine implementation.
///
/// It can be in one of states defined by [STATE]. State transitions
/// are triggered by events of type [EVENT].
///
/// Base on the definition each transition can trigger side effect
/// of type [SIDE_EFFECT].
class StateMachine<STATE, EVENT, SIDE_EFFECT> {
  factory StateMachine.create(
    BuildGraph<STATE, EVENT, SIDE_EFFECT> buildGraph,
  ) {
    final graphBuilder = GraphBuilder<STATE, EVENT, SIDE_EFFECT>();
    buildGraph(graphBuilder);
    return StateMachine._(graphBuilder.build());
  }

  StateMachine._(this._graph) : _currentState = _graph.initialState;

  /// Perform transition by emitting [event].
  Transition<STATE, EVENT, SIDE_EFFECT> transition(EVENT event) {
    final fromState = _currentState;
    final transition = _getTransition(fromState, event);
    _graph.onTransitionListeners.forEach((onTransition) {
      onTransition(transition);
    });
    transition.match((v) {
      _getOnStateExit(fromState)(fromState);
      _currentState = v.toState;
      if (!_graph.stateDefinitions.containsKey(v.toState.runtimeType)) {
        throw UnregisteredState('State ${v.toState} is not registered');
      }
      _getOnStateEnter(v.toState)(v.toState);
      _controller.add(_currentState);
    }, ignore);
    return transition;
  }

  /// Returns current state.
  STATE get currentState => _currentState;

  /// Returns [Stream] of states.
  Stream<STATE> get state => _controller.stream;

  final StreamController<STATE> _controller = StreamController.broadcast();

  final Graph<STATE, EVENT, SIDE_EFFECT> _graph;

  STATE _currentState;

  Transition<S, E, SIDE_EFFECT>
      _getTransition<S extends STATE, E extends EVENT>(S state, E event) {
    final createTransitionTo = _graph
        .stateDefinitions[state.runtimeType].transitions[event.runtimeType];
    if (createTransitionTo == null) return Transition.invalid(state, event);

    final transition = createTransitionTo(state, event);
    return Transition.valid(
      state,
      event,
      transition.toState,
      transition.sideEffect,
    );
  }

  VoidCallback<S> _getOnStateEnter<S extends STATE>(S state) =>
      _graph.stateDefinitions[state.runtimeType].onEnter;

  VoidCallback<S> _getOnStateExit<S extends STATE>(S state) =>
      _graph.stateDefinitions[state.runtimeType].onExit;
}

class UnregisteredState implements Exception {
  String message;

  UnregisteredState(this.message);

  @override
  String toString() => message;
}
