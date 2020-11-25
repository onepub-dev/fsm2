import 'package:fsm2/src/transitions/fork_transition.dart';
import 'package:fsm2/src/transitions/on_transition.dart';

import 'fork_builder.dart';
import 'graph_builder.dart';
import 'join_builder.dart';
import 'state_machine.dart';

import 'exceptions.dart';
import 'state_definition.dart';
import 'transitions/join_transition.dart';
import 'types.dart';

/// State builder.
///
/// Instance of this class is passed to [GraphBuilder.state] method.
class StateBuilder<S extends State> {
  final StateDefinition<S> _stateDefinition;

  StateBuilder(Type stateType) : _stateDefinition = StateDefinition<S>(stateType) {
    _stateDefinition.setParent( VirtualRoot().definition);
  }

  /// Statically declares a transition that will occur when Event of type [E]
  /// is sent to machine via [StateMachine.applyEvent] method.
  ///
  ///
  /// ```dart
  /// ..state<MobileNoAcquired>((builder) => builder
  ///   ..on<OnUserFound, LoggedIn>())
  /// ```
  ///
  /// The [condition] argument implements the UML concept a 'guard condition' and
  /// allows you to register multiple transitions for a single Event.
  /// Guard conditions allow you to implement a UML 'Choice psuedostate'.
  /// When the Event is fired each transition will be evaluated in the order
  /// they are added to the State.
  /// The first transition whose guard [condition] method returns true will be triggered, any later
  /// conditions will not be evaluated.
  ///
  /// ```dart
  /// ..state<MobileNoAcquired>((builder) => builder
  ///   ..on<OnUserFound, LoggedIn>(condition: (state, event) => event.subscribed == true))
  ///   ..on<OnUserFound, AskForSubscription>(condition: (state, event) => event.subscribed == false))
  /// ```
  ///
  /// There MAY be only one transition with a null [condition] and it MUST be the last
  /// transition added to the [S]. A transition with a null [condition] is considered the
  /// 'else' condition in that it fires if none of the transitions with a [condition] evaluate to true.
  ///
  /// An [NullChoiceMustBeLastException] will be thrown if you try to register two
  /// transitions for a given Event type with a null [condition] or you try to add a
  /// transition with a non-null [condition] after adding a transition with a null [condition].
  void on<E extends Event, TOSTATE extends State>({GuardCondition<E> condition, SideEffect sideEffect}) {
    var onTransition = OnTransition<S, E, TOSTATE>(_stateDefinition, condition, TOSTATE, sideEffect);

    _stateDefinition.addTransition<E>(onTransition);
  }

  void onFork<E extends Event>(BuildFork<E> buildFork, {Function(State, E) condition}) {
    final builder = ForkBuilder<E>();
    buildFork(builder);
    final definition = builder.build();

    var choice = ForkTransitionDefinition<S, E>(_stateDefinition, definition);

    _stateDefinition.addTransition(choice);
  }

  void onJoin<JS extends State>(BuildJoin<JS> buildJoin, {Function(JS, Event) condition}) {
    final builder = JoinBuilder<JS>(_stateDefinition);
    buildJoin(builder);
    final definition = builder.build();

    var choice = JoinTransitionDefinition(_stateDefinition, definition);

    _stateDefinition.addTransition(choice);
  }

  /// Adds a nested State definition as per the UML2
  /// specification for `hierarchically nested states`.
  void state<C extends State>(BuildState<C> buildState) {
    _stateDefinition.addNestedState(buildState);
  }

  /// Adds a costate State definition as per the UML2
  /// specification for `orthogonal regions`.
  void costate<CO extends State>(BuildState<CO> buildState) {
    _stateDefinition.addCoState(buildState);
  }

  /// Sets callback that will be called right after machine enters this State.
  void onEnter(OnEnter onEnter) {
    _stateDefinition.onEnter = onEnter;
  }

  /// Sets callback that will be called right before machine exits this State.
  void onExit(OnExit onExit) {
    _stateDefinition.onExit = onExit;
  }

  StateDefinition build() => _stateDefinition;

  void initialState<I extends State>() {}
}
