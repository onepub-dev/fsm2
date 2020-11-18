import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'package:fsm2/src/transition_definition.dart';
import 'package:fsm2/src/types.dart';
import 'package:synchronized/synchronized.dart';
import 'package:meta/meta.dart';

import 'dot_exporter.dart';
import 'exceptions.dart';
import 'graph.dart';
import 'graph_builder.dart';
import 'state_definition.dart';
import 'transition.dart';

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

  List<StateDefinition<State>> get topStateDefinitions => _graph.topStateDefinitions;

  /// Returns true if the [StateMachine] is in the given state.
  ///
  /// For a nested [State] the machine is said to be in current
  /// leaf [State] plus any parent state.
  ///
  /// ```dart
  ///
  /// final machine = StateMachine.create((g) => g
  ///    ..initialState(Solid())
  ///     ..state<Solid>((b) => b
  ///       ..state<Soft>((b) => b)
  ///       ..state<Hard>((b) => b)));
  /// ```
  /// If the above machine is in the leaf state 'Soft' then
  /// it is said to also be in the parent state 'Solid'.
  /// If a [StateMachine] has 'n' levels of nested state
  /// then it can be in  upto 'n' States at any given time.
  ///
  /// For a co-state [State] the machine is said to be in each
  /// co-state simultaneously.  Co-States can combine with nested
  /// states so that a [StateMachine] can be in all of the nested
  /// states for multiple co-states. So if a machine has two co-states
  /// and each co-state has 'n' nested states then a [StateMachine]
  /// could be in 2 * 'n' states plus any parents of each of the
  /// co-states.
  ///
  /// If [state] is not a known [State] then an [UnknownStateException]
  /// is thrown.
  bool isInState<S extends State>() {
    if (_currentState == S) return true;

    /// climb the tree of nested states.

    var def = _graph.findStateDefinition(_currentState);
    if (def == null) {
      throw UnknownStateException('The state ${S} has not been registered');
    }
    var parent = def.parent;
    while (parent != null) {
      if (parent.stateType == S) return true;

      parent = parent.parent;
    }
    return false;
  }

  /// Call this method with an [event] to transition to a new [State].
  ///
  /// Returns the a [Tranistion] object that describes the new [State]
  /// the FSM entered as a result of the event.
  ///
  /// Calls to [transition] are serialized as a transition must
  /// complete before the next transition begins (otherwise the state
  /// would be indeterminant).
  /// A queueing mechanism is used to avoid dead locks, as such
  /// you can call [transition] even whilst in the middle of a call to [transition].
  ///
  /// Throws a [UnknownStateException] if the [event] results in a
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

    Transition transition;
    try {
      transition = await _actualTransition(event.event);
      event.completer.complete(transition);
    } catch (e) {
      event.completer.completeError(e);
    }
  }

  Future<Transition> _actualTransition<E extends Event>(E event) async {
    /// only one transition at a time.
    return lock.synchronized(() async {
      final fromState = _currentState;

      var stateDefinition = _graph.findStateDefinition(fromState);
      var transitionDefinition = await stateDefinition.findTriggerableTransition(fromState, event);

      _graph.onTransitionListeners.forEach((onTransition) {
        onTransition(transitionDefinition);
      });

      var transition = await transitionDefinition.trigger(_graph, _currentState, event);
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
    var stateDefinitionMap = Map<Type, StateDefinition<State>>.from(_graph.stateDefinitions);

    var remainingStateMap = Map<Type, StateDefinition<State>>.from(_graph.stateDefinitions);

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

    /// check that no 'path' has the same state twice.
    // for (var stateDefinition in _graph.stateDefinitions.values) {
        
    //     var parent = stateDefinition.parent;
    //     while (parent != null)
    //     {
    //       if (parent.stateType == stateDefinition.stateType)
    //       {
    //         allGood = false;
    //         log()
    //       }
    //     }
    //     if (toState == null) {
    //       log('Found dynamic transition for ${transitionDefinition.eventType}, transition will be ignored.');
    //       foundDynamic = true;
    //       continue;
    //     }
    
    return allGood;
  }

  /// Exports the [StateMachine] to dot notation which can then
  /// be used by xdot to display a diagram of the state machine.
  ///
  /// apt install xdot
  ///
  /// https://www.graphviz.org/doc/info/lang.html
  ///
  /// The export can only deal with static transisions ([on] not [onDynamic])
  /// as it has no way of determining the final state for dynamic transitions.
  ///
  /// To visualise the resulting file graph run:
  ///
  /// ```
  /// xdot <path>
  /// ```
  Future<void> export(String path) async {
    var exporter = DotExporter(this);
    await exporter.export(path);
  }

  /// Traverses the State tree calling listener for each statically defined
  /// transition.
  Future<void> traverseTree(
      void Function(StateDefinition stateDefinition, TransitionDefinition transitionDefinition) listener) async {
    for (var stateDefinition in _graph.stateDefinitions.values) {
      for (var transitionDefinition in stateDefinition.getStaticTransitions()) {
        var toState = await transitionDefinition.toState;
        if (toState == null) {
          log('Found dynamic transition for ${transitionDefinition.eventType}, transition will be ignored.');
          continue;
        }

        await listener.call(stateDefinition, transitionDefinition);
      }
    }
  }

  StateDefinition<State> findStateDefinition(Type stateType) {
    return _graph.findStateDefinition(stateType);
  }
}
