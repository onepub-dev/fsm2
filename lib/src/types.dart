import 'builders/co_region_builder.dart';
import 'builders/fork_builder.dart';
import 'builders/graph_builder.dart';
import 'builders/state_builder.dart';
import 'definitions/co_region_definition.dart';
import 'definitions/state_definition.dart';
import 'state_machine.dart';

/// Base class for all States that you pass to the FSM.
///
/// All your [State] classes MUST extend this [State] class.
///
/// ```dart
/// class Solid extends State
/// {
/// }
///
///  final machine = StateMachine.create((g) => g
///       ..state<Solid>((b) => b
///
///       ...
/// )
/// ```
abstract class State {}

/// Special class used to represent the terminal state of the FSM.
/// If you add an 'on' transition to [TerminalState] then an
///  transition arrow to a terminal state
/// icon  will be displayed when you export your statemachine to a diagram.
class TerminalState extends State {}

/// Used by the [StateMachine.history] to represent a pseudo 'first' event that
/// that indicates how we got in the FSM initialState.
class InitialEvent extends Event {}

/// Base class for all Events that you pass to the FSM.
///
/// All your [Event] class MUST extends the [Event] class
///
/// ```dart
/// class Heat extends Event
/// {
///   int joules;
///
///   Heat({this.joules});
/// }
///
/// stateMachine.applyEvent(Heat(joules: 2000));
///
/// ...
///
/// ..on<Heat, Liquid>(condition: (s,e) => applyHeatAndReturnTemp(e.joules) > 0)
/// ```
abstract class Event {}

typedef GuardCondition<E> = bool Function(E event);
bool noGuardCondition(Event v) => true;

typedef BuildGraph = void Function(GraphBuilder);

typedef SideEffect<E extends Event> = Future<void> Function(E event);

/// The method signature for a [State]s [onEnter] method
typedef OnEnter = Future<void>? Function(Type fromState, Event? event);

/// The method signature for a [State]s [onExit] method
typedef OnExit = Future<void>? Function(Type toState, Event? event);

/// Callback when a transition occurs.
/// We pass, fromState, Event that triggered the transition
/// and the target state.
/// A single event may result in multiple calls to the listener when we have
/// active concurrent regions.
typedef TransitionListener = void Function(
    StateDefinition?, Event?, StateDefinition?);

/// The builder for a state.
typedef BuildState<S extends State> = void Function(StateBuilder<S>);

/// Builder for [CoRegionDefinition]
typedef BuildCoRegion<S extends State> = void Function(CoRegionBuilder<S>);

/// Builder for onFork
typedef BuildFork<E extends Event> = void Function(ForkBuilder<E>);

// /// Builder for onJoin
// typedef BuildJoin<S extends State> = void Function(JoinBuilder<S>);
