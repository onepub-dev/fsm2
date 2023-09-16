import 'dart:async';
import 'dart:collection';
import 'dart:developer';

import 'package:completer_ex/completer_ex.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

import 'builders/graph_builder.dart';
import 'definitions/state_definition.dart';
import 'exceptions.dart';
import 'export/exporter.dart';
import 'export/smcat.dart';
import 'graph.dart';
import 'state_of_mind.dart';
import 'state_path.dart';
import 'static_analysis.dart' as analysis;
import 'tracker.dart';
import 'transitions/on_transition.dart';
import 'transitions/transition_definition.dart';
import 'transitions/transition_notification.dart';
import 'types.dart';
import 'virtual_root.dart';

/// Finite State Machine implementation.
///
/// It can be in one of States defined by [State]. State transitions
/// are triggered by Events of type [Event].
///
///
class StateMachine {
  /// internal ctor
  StateMachine._(this._graph, {this.production}) {
    var initialState = _graph.initialState;

    /// If no initial state then the first state is the initial state.
    if (initialState == null && _graph.stateDefinitions.isNotEmpty) {
      _graph.initialState = initialState = _graph.stateDefinitions.values
          .firstWhere((sd) => sd.stateType != VirtualRoot)
          .stateType;
    }

    assert(initialState != null, 'initialState has not been initialised');

    if (!production!) {
      history.add(Tracker(_stateOfMind, initialEvent));
    }

    if (!_graph.isTopLevelState(initialState)) {
      throw InvalidInitialStateException(
          'The initialState $initialState MUST be a top level state.');
    }
  }

  /// Creates a statemachine using a builder pattern.
  ///
  /// The [production] flag controls whether
  /// [InvalidTransitionException] are thrown.
  /// We recommend setting [production] to true
  /// for your release code as it makes
  /// your system more forgiving to odd events that
  /// are sent when the FSM doesn't
  /// expect them. Instead these transitions are logged.
  ///
  /// [production] defaults to false.
  static Future<StateMachine> create(BuildGraph buildGraph,
      {bool production = false}) async {
    final graphBuilder = GraphBuilder();

    buildGraph(graphBuilder);
    final machine =
        StateMachine._(graphBuilder.build(), production: production);
    await machine._load();

    if (!production) {
      if (!machine.analyse()) {
        throw InvalidStateMachine('Check logs');
      }
    }

    return machine;
  }

  Future<void> _load() async {
    final initialSd = _graph.findStateDefinition(initialState)!;

    /// Find the initial state by chaining down through the
    /// initialStates looking for a leaf.
    if (!(await _loadStateOfMind(initialSd))) {
      throw InvalidInitialStateException(
          ''''The top level initialState $initialState must lead to a leaf state.''');
    }
  }

  /// only one transition can be happening at at time.
  final _lock = Lock();

  @visibleForTesting
  final initialEvent = InitialEvent();

  /// If production mode is off then we track
  /// each transition to aid with debugging.
  /// The first entry in the history will be the initial
  /// state.
  /// In production mode the list is empty.
  final history = <Tracker>[];

  /// To avoid deadlocks if an event is generated during
  /// a transition we queue transitions.
  final _eventQueue = Queue<_QueuedEvent>();

  /// Returns [Stream] of [StateOfMind].
  final StreamController<StateOfMind> _controller =
      StreamController.broadcast();

  final Graph _graph;

  var _stateOfMind = StateOfMind();

  final bool? production;

  /// The base of the state tree.
  StateDefinition<VirtualRoot> get virtualRoot => _graph.virtualRoot;

  /// 
  TransitionDefinition<InitialEvent> get initialTransition =>
      OnTransitionDefinition(
          virtualRoot, noopGuardCondition, VirtualRoot, null);

  Future<bool> _loadStateOfMind(StateDefinition<State> initialState) async {
    await initialState.onEnter(initialState.stateType, initialEvent);

    final transition = TransitionNotification(
        initialTransition, virtualRoot, initialEvent, initialState);
    _notifyListeners(transition);
    if (initialState.isLeaf) {
      addPath(_stateOfMind, StatePath.fromLeaf(_graph, initialState.stateType));
      return true;
    } else {
      /// search child for a leaf.
      final child = initialState.findStateDefintion(initialState.initialState,
          includeChildren: false)!;
      return _loadStateOfMind(child);
    }
  }

  List<StateDefinition<State>> get topStateDefinitions =>
      _graph.topStateDefinitions;

  String? get initialStateLabel => _graph.initialStateLabel;

  Type? get initialState => _graph.initialState;

  /// Returns true if the [StateMachine] is in the given state.
  ///
  /// Calling [isInState] will wait for the [StateMachine] to complete before
  /// checking the state.
  ///
  /// For a nested [State] the machine is said to be in the current
  /// leaf [State] plus any parent state.
  ///
  /// ```dart
  ///   machine.isInState<Hard>()
  /// ```
  ///
  /// When using a coregion then you can be in multiple leaf states
  /// concurrently.
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
  /// For a [StateMachine.coregion()] the machine is said to be in each
  /// coregion simultaneously.  Coregions can combine with nested
  /// states so that a [StateMachine] can be in all of the nested
  /// states for multiple coregions. So if a machine has two coregions
  /// and each coregion has 'n' nested states then a [StateMachine]
  /// could be in 2 * 'n' states plus any parents of each of the
  /// coregions.
  ///
  /// If [S] is not a known [State] then an [UnknownStateException]
  /// is thrown.
  Future<bool> isInState<S extends State>() async {
    await complete;
    if (_stateOfMind.isInState(S)) {
      return true;
    }

    /// climb the tree of nested states.

    final def = _graph.findStateDefinition(S);
    if (def == null) {
      throw UnknownStateException('The state $S has not been registered');
    }
    var parent = def.parent!;
    while (parent.stateType != VirtualRoot) {
      if (parent.stateType == S) {
        return true;
      }

      parent = parent.parent!;
    }
    return false;
  }

  @visibleForTesting
  StateOfMind get stateOfMind => _stateOfMind;

  /// Call this method with an [event] to transition to a new [State].
  ///
  /// Calls to [applyEvent] are serialized as a transition must
  /// complete before the next transition begins (otherwise the state
  /// would be indeterminant).
  ///
  /// A queueing mechanism is used to avoid dead locks, as such
  /// you can call [applyEvent] even whilst in the
  /// middle of a call to [applyEvent].
  ///
  /// Events MUST be handled asynchronously.
  /// If you need to take an action once an event completes you need to use
  /// a [SideEffect] or [onEnter].
  ///
  /// Throws a [UnknownStateException] if the [event] results in a
  /// transition to a [State] that hasn't been registered.
  ///
  /// Throws an [InvalidTransitionException] if the event is applied when
  /// we are in a state that doesn't support the given event.
  /// When in [production] mode we supress this exception to make the FSM
  /// more forgiving.
  ///
  void applyEvent<E extends Event>(E event) {
    final qe = _QueuedEvent(event);
    log('FSM queuing $event');
    _eventQueue.add(qe);

    /// process the event on a microtask.
    Future.delayed(Duration.zero, _dispatch);
  }

  /// dequeue the next event and transition it.
  Future<void> _dispatch() async {
    assert(_eventQueue.isNotEmpty, 'The event queue is in an invalid state');
    final event = _eventQueue.first;

    try {
      log('FSM applying ${event.event}');
      await _actualApplyEvent(event.event);
      log('FSM applied ${event.event}');
      event._completer.complete();
    } on InvalidTransitionException catch (e) {
      log('FSM InvalidTransitionException for ${event.event}');
      if (production!) {
        log('FSM InvalidTransitionException suppressed: $e');

        event._completer.complete();
      } else {
        event._completer.completeError(e);
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log('FSM Exception applying ${event.event}');
      event._completer.completeError(e);
    } finally {
      /// now we have finished processing the event
      /// we can remove it from the queue.
      log('FSM removing applied ${event.event} from eventQueue');
      _eventQueue.removeFirst();
    }
  }

  /// Returns true if the event queue is empty
  bool get _isQuiescent => _eventQueue.isEmpty;

  /// waits until all events have been processed.
  /// @visibleForTesting
  @Deprecated('Use complete')
  Future<void> get waitUntilQuiescent async {
    while (!_isQuiescent) {
      await _eventQueue.last._completer.future;
    }
  }

  /// Call this method to ensure that your [StateMachine] has completed
  /// processing all [Event]s.
  /// The [StateMachine] is considered to be in an indeterminate state
  /// until this method completes.
  /// If can submit additional events after calling [complete] but
  /// you must then call [complete] again to ensure the new
  /// events have been processed.
  ///
  /// ```dart
  /// await statemachine.complete;
  /// ```
  Future<void> get complete async {
    while (!_isQuiescent) {
      await _eventQueue.last._completer.future;
    }
  }

  Future<void> _actualApplyEvent<E extends Event>(E event) async =>

      /// only one transition at a time.
      _lock.synchronized(() async {
        var dispatched = false;
        for (final stateDefinition in _stateOfMind.activeLeafStates()) {
          final transitionDefinition = await stateDefinition
              .findTriggerableTransition(stateDefinition.stateType, event);
          if (transitionDefinition == null) {
            continue;
          }

          await _applyTransitions(stateDefinition, transitionDefinition, event);
          dispatched = true;
        }

        if (!dispatched) {
          throw InvalidTransitionException(_stateOfMind, event);
        }

        if (production == false) {
          history.add(Tracker(_stateOfMind, event));
        }

        _controller.add(_stateOfMind);
      });

  /// Checks that every leaf in the [StateMachine] can be reached.
  /// Use this method during development to ensure your [StateMachine]
  /// is in a consistent state.
  bool analyse() => analysis.analyse(_graph);

  /// Returns [Stream] of [StateOfMind] which
  /// reflects the [StateMachine]s complete state each
  /// time a state change occurs.
  ///
  //
  /// Remember that with Nested States a FSM
  /// can be in multiple states.
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
  ExportedPages export(String path) {
    //var exporter = MermaidExporter(this);
    final exporter = SMCatExporter(this);
    return exporter.export(path);
  }

  /// Traverses the State tree calling listener for each state
  /// and each statically defined transition.
  /// This method is intended to help you debug your [StateMachine].
  Future<void> traverseTree(
      void Function(StateDefinition stateDefinition,
              List<TransitionDefinition> transitionDefinitions)
          listener,
      {bool includeInherited = true}) async {
    for (final stateDefinition in _graph.stateDefinitions.values) {
      listener.call(stateDefinition,
          stateDefinition.getTransitions(includeInherited: includeInherited));
    }
  }

  StateDefinition<State>? _findStateDefinition(Type? stateType) =>
      _graph.findStateDefinition(stateType);

  /// Returns the oldest ancestor for the state.
  /// If the state has no ancestors then we return the state.
  /// The VirtualRoot is not considered an ancestor and will
  /// never be returned.
  Type _oldestAncestor(Type? state) {
    final sd = _findStateDefinition(state)!;

    var ancestor = sd;

    var parent = sd.parent!;
    while (parent.stateType != VirtualRoot) {
      ancestor = parent;
      parent = parent.parent!;
    }

    return ancestor.stateType;
  }

  Future<void> _applyTransitions<E extends Event>(StateDefinition<State>? from,
      TransitionDefinition<E> transitionDefinition, Event event) async {
    /// When an event occurs on a join we need to trigger multiple transitions
    final transitions = transitionDefinition.transitions(_graph, from, event);

    /// we only apply exit and sideEffect to the stateOfMind
    /// for the first transition.
    var applySideEffects = true;
    for (final transition in transitions) {
      // final _transition = cast(transition.event, transition)!;
      _stateOfMind = await transition.definition.trigger(
          _graph, _stateOfMind, transition,
          applySideEffects: applySideEffects);
      applySideEffects = false;
      _notifyListeners(transition);
    }
  }

  /// Notifiy each transition listener of each transition that has occured.
  void _notifyListeners(TransitionNotification transition) {
    for (final onTransition in _graph.onTransitionListeners) {
      if (!production!) {
        log('''transition: from: ${transition.from!.stateType} event: ${transition.event.runtimeType} to: ${transition.to!.stateType}''');
      }

      onTransition(transition.from, transition.event, transition.to);
    }
  }
}

/// Used to hide internal implementation details
Type oldestAncestor(StateMachine stateMachine, Type? state) =>
    stateMachine._oldestAncestor(state);

StateDefinition<State>? findStateDefinition(
        StateMachine stateMachine, Type? stateType) =>
    stateMachine._findStateDefinition(stateType);

class _QueuedEvent {
  _QueuedEvent(this.event);
  Event event;
  final _completer = CompleterEx<void>();
}
