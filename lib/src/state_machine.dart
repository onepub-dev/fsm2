import 'package:dfunc/dfunc.dart';
import 'package:fsm/src/graph.dart';
import 'package:fsm/src/transition.dart';

class StateMachine<STATE, EVENT, SIDE_EFFECT> {
  StateMachine._(this._graph) : state = _graph.initialState;

  Transition<STATE, EVENT, SIDE_EFFECT> transition(EVENT event) {
    final fromState = state;
    final transition = getTransition(fromState, event);
    transition.match((v) => state = v.toState, ignore);
    return transition;
  }

  final Graph<STATE, EVENT, SIDE_EFFECT> _graph;

  STATE state;

  factory StateMachine.create(
      BuildGraph<STATE, EVENT, SIDE_EFFECT> buildGraph) {
    final graphBuilder = GraphBuilder<STATE, EVENT, SIDE_EFFECT>();
    buildGraph(graphBuilder);
    return StateMachine._(graphBuilder.build());
  }

  Transition<STATE, EVENT, SIDE_EFFECT> getTransition(
      STATE state, EVENT event) {
    final createTransitionTo = _graph
        .stateDefinitions[state.runtimeType].transitions[event.runtimeType];
    if (createTransitionTo == null) {
      return Transition.invalid(Invalid(state, event));
    }
    final transition = createTransitionTo(state, event);
    return Transition.valid(Valid(
        state, event, transition.toState, Optional.of(transition.sideEffect)));
  }
}
