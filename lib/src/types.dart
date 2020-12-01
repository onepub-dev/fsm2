import 'package:fsm2/src/co_region_builder.dart';

import 'fork_builder.dart';
import 'graph_builder.dart';
import 'join_builder.dart';
import 'state_builder.dart';
import 'state_definition.dart';

abstract class State {}

/// Class used to represent an implicit terminal [State].
///
/// A [State] is considered terminal if it has no explicit transitions ([on], [onFork], [onJoin])
/// events defined for it.
// class TerminalState extends State {}

/// Special class used to represent the final/terminal state of the FSM.
/// If you add an 'on' transition to [FinalState] then an transition arrow to a final state
/// icon  will be displayed when you export your statemachine to a diagram.
class FinalState extends State {}

/// Class used to represent an implicit event to a terminal [State].
///
/// A [State] is considered terminal if it has no explicit transitions ([on], [onFork], [onJoin])
/// events defined from it (e.g. there is no way to leave the state).
///
/// If a [State] is a terminal state we emmit an implicit transition from the [State] to
/// the [TerminalState] via a [TerminalEvent].
// class TerminalEvent extends Event {}

abstract class Event {}

typedef GuardCondition<E extends Event> = bool Function(E event);

typedef BuildGraph = void Function(GraphBuilder);

typedef SideEffect = Future<void> Function();

typedef OnEnter = Future<void> Function(Type fromState, Event event);
typedef OnExit = Future<void> Function(Type toState, Event event);

/// Callback when a transition occurs.
/// We pass, fromState, Event that triggered the transition and the target state.
typedef TransitionListener = void Function(
    StateDefinition, Event, StateDefinition);

/// The builder for a state.
typedef BuildState<S extends State> = void Function(StateBuilder<S>);

/// Builder for [coregion]
typedef BuildCoRegion<S extends State> = void Function(CoRegionBuilder<S>);

/// Builder for onFork
typedef BuildFork<E extends Event> = void Function(ForkBuilder<E>);

/// Builder for onJoin
typedef BuildJoin<S extends State> = void Function(JoinBuilder<S>);
