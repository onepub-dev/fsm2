import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'package:fsm2/src/state_of_mind.dart';
import 'package:fsm2/src/types.dart';
import 'package:synchronized/synchronized.dart';

import 'exceptions.dart';
import 'export/state_machine_cat_v2.dart';
import 'graph.dart';
import 'graph_builder.dart';
import 'state_definition.dart';
import 'state_path.dart';
import 'static_analysis.dart' as analysis;
import 'transitions/transition_definition.dart';

/// Finite State Machine implementation.
///
/// It can be in one of States defined by [State]. State transitions
/// are triggered by Events of type [Event].
///
///

class _QueuedEvent {
  Event event;
  Completer<StateOfMind> completer = Completer();

  _QueuedEvent(this.event);
}

class StateMachine {
  /// only one transition can be happening at at time.
  final lock = Lock();

  /// To avoid deadlocks if an event is generated during
  /// a transition we queue transitions.
  final eventQueue = Queue<_QueuedEvent>();

  /// Returns [Stream] of States.
  final StreamController<StateOfMind> _controller = StreamController.broadcast();

  final Graph _graph;

  var _stateOfMind = StateOfMind();

  final bool production;

  /// Creates a statemachine using a builder pattern.
  ///
  /// The [production] flag controls whether [InvalidTransitionException] are thrown.
  /// We recommend setting [production] to true for your release code as it makes
  /// your system more forgiving to odd events that are sent when the FSM doesn't
  /// expect them. Instead these transitions are logged.
  ///
  /// [production] defaults to false.
  factory StateMachine.create(BuildGraph buildGraph, {bool production = false}) {
    final graphBuilder = GraphBuilder();

    buildGraph(graphBuilder);
    var machine = StateMachine._(graphBuilder.build(), production: production);

    if (!production && !machine.analyse()) {
      throw InvalidStateMachine('Check logs');
    }

    return machine;
  }

  StateMachine._(this._graph, {this.production}) {
    var initialState = _graph.initialState;

    /// If no initial state then the first state is the initial state.
    if (initialState == null && _graph.stateDefinitions.isNotEmpty) {
      initialState = _graph.stateDefinitions[0].stateType;
    }

    assert(initialState != null);

    if (!_graph.isTopLevelState(initialState)) {
      throw InvalidInitialStateException('The initialState $initialState MUST be a top level state.');
    }

    var initialSd = _graph.findStateDefinition(initialState);

    /// Find the initial state by chaining down through the initialStates looking for a leaf.
    if (!_loadStateOfMind(initialSd)) {
      throw InvalidInitialStateException('The top level initialState $initialState must lead to a leaf state.');
    }
  }

  bool _loadStateOfMind(StateDefinition<State> initialState) {
    if (initialState.isLeaf) {
      _stateOfMind.addPath(StatePath.fromLeaf(_graph, initialState.stateType));
      return true;
    } else {
      /// search child for a leaf.
      var child = initialState.findStateDefintion(initialState.initialState, includeChildren: false);
      return _loadStateOfMind(child);
    }
  }

  List<StateDefinition<State>> get topStateDefinitions => _graph.topStateDefinitions;

  String get initialStateLabel => _graph.initialStateLabel;

  Type get initialState => _graph.initialState;

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
  /// For a [coregion] the machine is said to be in each
  /// [coregion] simultaneously.  Coregions can combine with nested
  /// states so that a [StateMachine] can be in all of the nested
  /// states for multiple [coregion]s. So if a machine has two [coregion]s
  /// and each [coregion] has 'n' nested states then a [StateMachine]
  /// could be in 2 * 'n' states plus any parents of each of the
  /// [coregion]s.
  ///
  /// If [state] is not a known [State] then an [UnknownStateException]
  /// is thrown.
  bool isInState<S extends State>() {
    if (_stateOfMind.isInState(S)) return true;

    /// climb the tree of nested states.

    var def = _graph.findStateDefinition(S);
    if (def == null) {
      throw UnknownStateException('The state ${S} has not been registered');
    }
    var parent = def.parent;
    while (parent != VirtualRoot().definition) {
      if (parent.stateType == S) return true;

      parent = parent.parent;
    }
    return false;
  }

  StateOfMind get stateOfMind {
    return _stateOfMind;
  }

  /// Call this method with an [event] to transition to a new [State].
  ///
  /// Returns a [StateOfMind] object that describes the new set of [State]s
  /// the FSM entered as a result of the event.
  ///
  /// Calls to [applyEvent] are serialized as a transition must
  /// complete before the next transition begins (otherwise the state
  /// would be indeterminant).
  ///
  /// A queueing mechanism is used to avoid dead locks, as such
  /// you can call [applyEvent] even whilst in the middle of a call to [applyEvent].
  ///
  /// Throws a [UnknownStateException] if the [event] results in a
  /// transition to a [State] that hasn't been registered.
  ///
  /// Throws an [InvalidTransitionException] if the event is applied when
  /// we are in a state that doesn't support the given event.
  /// When in [production] mode we supress this exception to make the FSM
  /// more forgiving.
  ///
  Future<StateOfMind> applyEvent<E extends Event>(E event) async {
    var qe = _QueuedEvent(event);
    eventQueue.add(qe);

    /// process the event on a microtask.
    Future.delayed(Duration(microseconds: 0), () => _dispatch());
    return qe.completer.future;
  }

  /// dequeue the next event and transition it.
  void _dispatch() async {
    assert(eventQueue.isNotEmpty);
    var event = eventQueue.removeFirst();

    try {
      _stateOfMind = await _actualApplyEvent(event.event);
      event.completer.complete(stateOfMind);
    } on InvalidTransitionException catch (e) {
      if (production) {
        print('InvalidTransitionException suppressed: $e');

        /// We just return the current [StateOfMind]
        event.completer.complete(_stateOfMind);
      } else {
        event.completer.completeError(e);
      }
    } catch (e) {
      event.completer.completeError(e);
    }
  }

  Future<StateOfMind> _actualApplyEvent<E extends Event>(E event) async {
    /// only one transition at a time.
    return lock.synchronized(() async {
      for (var stateDefinition in _stateOfMind.activeLeafStates()) {
        var transitionDefinition = await stateDefinition.findTriggerableTransition(stateDefinition.stateType, event);

        _graph.onTransitionListeners.forEach((onTransition) {
          // Some transitions (fork) have multiple targets so we need to
          // report a transition to each of them.
          for (var targetStateType in transitionDefinition.targetStates) {
            var targetState = _graph.findStateDefinition(targetStateType);
            if (!production) {
              log('transition: from: ${stateDefinition.stateType} event: ${event.runtimeType} to: ${targetState.stateType}');
            }
            onTransition(stateDefinition, event, targetState);
          }
        });

        _stateOfMind = await transitionDefinition.trigger(_graph, _stateOfMind, stateDefinition.stateType, event);
        _controller.add(_stateOfMind);
      }

      return _stateOfMind;
    });
  }

  bool analyse() {
    return analysis.analyse(_graph);
  }

  /// Returns [Stream] of state types.
  /// Each time the FSM changes state the new
  /// state Type is added to the broadcast stream allowing
  /// you to monitor the transition of states.
  ///
  /// Remember that with Nested States a FSM
  /// can be in multiple states the stream will only
  /// reflect the state the FMS was directly moved into.
  /// Any ancestor states that are consequentially moved into
  /// will not be reflected in the stream.
  Stream<StateOfMind> get stream => _controller.stream;

  /// Exports the [StateMachine] to dot notation which can then
  /// be used by xdot to display a diagram of the state machine.
  ///
  /// apt install xdot
  ///
  /// https://www.graphviz.org/doc/info/lang.html
  ///
  ///
  /// To visualise the resulting file graph run:
  ///
  /// ```
  /// xdot <path>
  /// ```
  Future<void> export(String path) async {
    //var exporter = MermaidExporter(this);
    var exporter = StartMachineCatV2Exporter(this);
    await exporter.export(path);
  }

  /// Traverses the State tree calling listener for each state
  /// and each statically defined transition.
  Future<void> traverseTree(
      void Function(StateDefinition stateDefinition, List<TransitionDefinition> transitionDefinitions) listener,
      {bool includeInherited = true}) async {
    for (var stateDefinition in _graph.stateDefinitions.values) {
      await listener.call(stateDefinition, stateDefinition.getTransitions(includeInherited: includeInherited));
    }
  }

  StateDefinition<State> findStateDefinition(Type stateType) {
    return _graph.findStateDefinition(stateType);
  }

  /// Returns the oldest ancestor for the state.
  /// If the state has no ancestors then we return the state.
  /// The VirtualRoot is not considered an ancestor and will
  /// never be returned.
  Type oldestAncestor(Type state) {
    var sd = findStateDefinition(state);

    var ancestor = sd;

    var parent = sd.parent;
    while (parent != VirtualRoot().definition) {
      ancestor = parent;
      parent = parent.parent;
    }

    return ancestor.stateType;
  }
}
