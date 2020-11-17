import 'package:fsm2/src/graph_builder.dart';
import 'package:fsm2/src/state_builder.dart';
import 'package:fsm2/src/transition.dart';

import 'transition_definition.dart';

abstract class State {}

abstract class Event {}

typedef Condition<S extends State, E extends Event> = bool Function(Type state, E event);

typedef BuildGraph = void Function(GraphBuilder);

typedef SideEffect = void Function();

typedef OnEnter = void Function(Type fromState, Event event);
typedef OnExit = void Function(Type toState, Event event);

typedef TransitionListener = void Function(TransitionDefinition);
typedef EventHandler<E extends Event> = Future<Transition> Function(Type state, E e);

/// The builder.
typedef BuildState<S extends State> = void Function(StateBuilder<S>);
