import 'dart:async';

import 'package:dfunc/dfunc.dart';
import 'package:fsm/src/graph.dart';
import 'package:fsm/src/transition.dart';

class StateMachine<STATE, EVENT, SIDE_EFFECT> {
  StateMachine._(this._graph) : _currentState = _graph.initialState;

  final StreamController<STATE> _controller = StreamController.broadcast();

  Transition<STATE, EVENT, SIDE_EFFECT> transition(EVENT event) {
    final fromState = _currentState;
    final transition = getTransition(fromState, event);
    _graph.onTransitionListeners.forEach((onTransition) {
      onTransition(transition);
    });
    transition.match((v) {
      _currentState = v.toState;
      _controller.add(_currentState);
    }, ignore);
    return transition;
  }

  STATE get currentState => _currentState;

  Stream<STATE> get state => _controller.stream;

  final Graph<STATE, EVENT, SIDE_EFFECT> _graph;

  STATE _currentState;

  factory StateMachine.create(
      BuildGraph<STATE, EVENT, SIDE_EFFECT> buildGraph) {
    final graphBuilder = GraphBuilder<STATE, EVENT, SIDE_EFFECT>();
    buildGraph(graphBuilder);
    return StateMachine._(graphBuilder.build());
  }

  Transition<STATE, EVENT, SIDE_EFFECT> getTransition(
    STATE state,
    EVENT event,
  ) {
    final createTransitionTo = _graph
        .stateDefinitions[state.runtimeType].transitions[event.runtimeType];
    if (createTransitionTo == null) {
      return Transition.invalid(state, event);
    }
    final transition = createTransitionTo(state, event);
    return Transition.valid(
      state,
      event,
      transition.toState,
      transition.sideEffect,
    );
  }
}
