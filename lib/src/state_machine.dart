import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'package:synchronized/synchronized.dart';
import 'package:meta/meta.dart';

import 'exceptions.dart';
import 'graph.dart';
import 'graph_builder.dart';
import 'state_builder.dart';

abstract class State {}

abstract class Event {}

/// Finite State Machine implementation.
///
/// It can be in one of States defined by [State]. State transitions
/// are triggered by Events of type [Event].
///
///

class QueuedEvent {
  Event event;
  Completer<Transition> completer = Completer();

  QueuedEvent(this.event);
}

class StateMachine {
  /// Returns current State.
  Type get currentState => _currentState;

  /// only one transition can be happening at at time.
  final lock = Lock(enableStackTraces: true);

  /// To avoid deadlocks if an event is generated during
  /// a transition we queue transitions.
  final eventQueue = Queue<QueuedEvent>();

  /// Returns [Stream] of States.
  final StreamController<Type> _controller = StreamController.broadcast();

  final Graph _graph;

  Type _currentState;

  factory StateMachine.create(BuildGraph buildGraph) {
    final graphBuilder = GraphBuilder();

    buildGraph(graphBuilder);
    var machine = StateMachine._(graphBuilder.build());

    return machine;
  }

  StateMachine._(this._graph) : _currentState = _graph.initialState;

  /// Call this method with an [event] to transition to a new [State].
  /// Returns the a [Tranistion] object that describes the new [State]
  /// the FSM entered as a result of the event.
  ///
  /// Calls to [transition] are serialized as a transition must
  /// complete before the next transition begins (otherwise the state
  /// would be indeterminant).
  /// A queueing mechanism is used to avoid dead locks, as such
  /// you can call [transition] even whilst in the middle of a call to [transition].
  ///
  /// Throws a [UnregisteredStateException] if the [event] results in a
  /// transition to a [State] that hasn't been registered.
  ///
  Future<Transition> transition<E extends Event>(E event) async {
    var qe = QueuedEvent(event);
    eventQueue.add(qe);

    /// process the event on a microtask.
    Future.delayed(Duration(microseconds: 0), () => _dispatch());
    return qe.completer.future;
  }

  /// dequeue the next event and transition it.
  void _dispatch() async {
    assert(eventQueue.isNotEmpty);
    var event = eventQueue.removeFirst();

    var transition = await _actualTransition(event.event);
    event.completer.complete(transition);
  }

  Future<Transition> _actualTransition<E extends Event>(E event) async {
    /// only one transition at a time.
    return lock.synchronized(() async {
      final fromState = _currentState;

      var stateDefinition = _graph.findStateDefinition(fromState.runtimeType);
      var transitionDefinition = await stateDefinition.findTransition(fromState, event);

      // if (!_graph.stateDefinitions.containsKey(transitionDefinition.toState.runtimeType)) {
      //   throw UnregisteredStateException('State ${transitionDefinition.toState} is not registered');
      // }

      _graph.onTransitionListeners.forEach((onTransition) {
        onTransition(transitionDefinition);
      });

      var transition = await transitionDefinition.trigger(_graph, event);
      _currentState = (await transition).toState;
      _controller.add(_currentState);

      return transition;
    });
  }

  /// Checks the state machine to ensure that every [State]
  /// can be reached.
  /// We do this by checking that each state has at
  /// least one event that leads to that [State].
  /// The [analyse] method will only work if all [State]
  /// transitions are explicity declared. If you use any
  /// dynamic transitions (where you have a function that
  /// works out the transition) then the call to [analyse]
  /// will fail.
  /// The [analyse] method logs any problems it finds.
  ///
  /// Returns [true] if all States are reachable.
  @visibleForTesting
  Future<bool> analyse() async {
    var allGood = true;
    var stateDefinitionMap = Map.from(_graph.stateDefinitions);

    var remainingStateMap = Map.from(_graph.stateDefinitions);

    var foundDynamic = false;

    remainingStateMap.remove(_graph.initialState);

    for (var stateDefinition in stateDefinitionMap.values) {
      log('Found state: ${stateDefinition.stateType}');
      for (var transitionDefinition in stateDefinition.getStaticTransitions()) {
        var toState = await transitionDefinition.toState;
        if (toState == null) {
          log('Found dynamic transition for ${transitionDefinition.eventType}, transition will be ignored.');
          foundDynamic = true;
          continue;
        }

        remainingStateMap.remove(toState);
      }
    }

    if (remainingStateMap.isNotEmpty) {
      allGood = false;
      if (foundDynamic) {
        log('As Dynamic transitions were found the analysis may find unreachable States. Try changing any [onDynamic] calls to [on] calls');
      }
      log('The following States cannot be reached.');

      for (var state in remainingStateMap.values) {
        log('State: ${state.stateType}');
      }
    }
    return allGood;
  }
}

typedef OnEnter = void Function(Type fromState, Event event);
typedef OnExit = void Function(Type toState, Event event);
