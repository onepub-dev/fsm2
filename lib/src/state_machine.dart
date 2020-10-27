import 'dart:async';

import 'exceptions.dart';
import 'graph.dart';
import 'graph_builder.dart';
import 'state_builder.dart';
import 'transition.dart';

abstract class State {}

abstract class Event {}

/// Finite State Machine implementation.
///
/// It can be in one of States defined by [State]. State transitions
/// are triggered by Events of type [Event].
///

class StateMachine {
  /// Returns current State.
  State get currentState => _currentState;

  /// Returns [Stream] of States.
  // Stream<State> get State => _controller.stream;

  final StreamController<State> _controller = StreamController.broadcast();

  final Graph _graph;

  State _currentState;

  factory StateMachine.create(
    BuildGraph buildGraph,
  ) {
    final graphBuilder = GraphBuilder();
    buildGraph(graphBuilder);
    return StateMachine._(graphBuilder.build());
  }

  StateMachine._(this._graph) : _currentState = _graph.initialState;

  /// Call this method with an [event] to transition to a new [State].
  /// Returns the new [state] the FSM entered as a result of the event.
  ///
  /// Throws a [UnregisteredStateException] if the [event] results in a
  /// transition to a [State] that hasn't been registered.
  ///
  Transition transition<E extends Event>(E event) {
    final fromState = _currentState;
    final transitionDefinition = _getTransition(fromState, event);

    if (!_graph.stateDefinitions.containsKey(transitionDefinition.toState.runtimeType)) {
      throw UnregisteredStateException('State ${transitionDefinition.toState} is not registered');
    }

    _graph.onTransitionListeners.forEach((onTransition) {
      onTransition(transitionDefinition);
    });

    var transition = transitionDefinition.trigger(_graph);
    _currentState = transition.toState;
    _controller.add(_currentState);

    return transition;
  }

  TransitionDefinition _getTransition<S extends State, E extends Event>(S state, E event) {
    return _graph.stateDefinitions[state.runtimeType].getTransition(state, event);
  }
}

typedef OnEnter = void Function(State fromState, Event Event);
typedef OnExit = void Function(State toState, Event Event);
