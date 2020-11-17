import 'event_choices.dart';
import 'graph_builder.dart';
import 'state_machine.dart';
import 'transition.dart';

import 'exceptions.dart';
import 'state_definition.dart';
import 'types.dart';

/// State builder.
///
/// Instance of this class is passed to [GraphBuilder.state] method.
class StateBuilder<S extends State> {
  final StateDefinition<S> _stateDefinition;

  StateBuilder(Type stateType) : _stateDefinition = StateDefinition<S>(stateType);

  /// Sets a dynamically defined transition that will be called when Event of type [E]
  /// is sent to machine via [StateMachine.transition] method.
  ///
  /// You should prefer using the [on] method with a statically declared state transition
  /// wherever possible as it makes static analysis of the [StateMachine] possible by
  /// calling [StateMachine.analysis()].
  ///
  /// The [eventHandler] is called when [StateMachine.transition] is called
  /// with the the [Event] define by [E]. The eventHandler should be used to transition
  /// the FSM to a new state by calling [StateBuilder.transitionTo].
  ///
  /// ```dart
  /// ..state<MobileNoAcquired>((builder) => builder
  ///   ..on<UserFound>((state, event) => builder.transitionTo(Login())))
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
  ///   ..on<UserFound>((state, event) => builder.transitionTo(Login())
  ///       , condition: (state, event) => event.subscribed == true))
  ///   ..on<UserFound>((state, event) => builder.transitionTo(AskForSubscription())
  ///       , condition: (state, event) => event.subscribed == false))
  /// ```
  ///
  /// There MAY be only one transition with a null [condition] and it MUST be the last
  /// transition added to the [S]. A transition with a null [condition] is considered the
  /// 'else' condition in that it fires if none of the transitions with a [condition] evaluate to true.
  ///
  /// An [NullChoiceMustBeLastException] will be thrown if you try to register two
  /// transitions for a given Event type with a null [condition] or you try to add a
  /// transition with a non-null [condition] after adding a transition with a null [condition].
  void onDynamic<E extends Event>(EventHandler<E> eventHandler, {Condition<S, E> condition}) {
    //   _StateDefinition.transitions[E] = (State s, Event e) => createTransitionTo(s, e);

    var choices = _stateDefinition.transitions[E];
    assert(choices == null || choices.eventType == E);

    if (choices == null) {
      choices = EventChoices<S, E>();
      choices.eventType = E;
    }

    // as this is a dynamic choice we don't know the toState
    // so we just use the fromState as a place holder that is
    // ignored.
    var eventChoice = EventChoice<S, E, S>();

    eventChoice.condition = condition;
    eventChoice.eventHandler = eventHandler;

    /// there may only be one transition for a given Event with a null choice function
    /// and it must be the last transition added.
    _checkHasNoNullChoices<E>(choices);

    choices.eventChoices.add(eventChoice);

    _stateDefinition.transitions[E] = choices;
  }

  /// Statically declares a transition that will occur when Event of type [E]
  /// is sent to machine via [StateMachine.transition] method.
  ///
  /// Use this method in preference to the [onDynamic] method as it allows
  /// for static analysis of your state machine.
  ///
  /// The [eventHandler] is called when [StateMachine.transition] is called
  /// with the the [Event] define by [E]. The eventHandler should be used to transition
  /// the FSM to a new state by calling [StateBuilder.transitionTo].
  ///
  /// ```dart
  /// ..state<MobileNoAcquired>((builder) => builder
  ///   ..on<UserFound>((state, event) => builder.transitionTo(Login())))
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
  ///   ..on<UserFound>((state, event) => builder.transitionTo(Login())
  ///       , condition: (state, event) => event.subscribed == true))
  ///   ..on<UserFound>((state, event) => builder.transitionTo(AskForSubscription())
  ///       , condition: (state, event) => event.subscribed == false))
  /// ```
  ///
  /// There MAY be only one transition with a null [condition] and it MUST be the last
  /// transition added to the [S]. A transition with a null [condition] is considered the
  /// 'else' condition in that it fires if none of the transitions with a [condition] evaluate to true.
  ///
  /// An [NullChoiceMustBeLastException] will be thrown if you try to register two
  /// transitions for a given Event type with a null [condition] or you try to add a
  /// transition with a non-null [condition] after adding a transition with a null [condition].
  void on<E extends Event, TOSTATE extends State>({Condition<S, E> condition, SideEffect sideEffect}) {
    //   _StateDefinition.transitions[E] = (State s, Event e) => createTransitionTo(s, e);

    var choices = _stateDefinition.transitions[E];
    if (choices == null) {
      choices = EventChoices<S, E>();
      choices.eventType = E;
    }

    var eventChoice = EventChoice<S, E, TOSTATE>();

    eventChoice.condition = condition;
    eventChoice.toState = TOSTATE;
    eventChoice.sideEffect = sideEffect;

    /// there may only be one transition for a given Event with a null choice function
    /// and it must be the last transition added.
    _checkHasNoNullChoices<E>(choices);

    choices.eventChoices.add(eventChoice);

    _stateDefinition.transitions[E] = choices;
  }

  /// Adds a nested State definition as per the UML2
  /// specification for `hierarchically nested states`.
  void state<C extends State>(
    BuildState<C> buildState,
  ) {
    _stateDefinition.addNestedState(buildState);
  }

  /// Adds a nested State definition as per the UML2
  /// specification for `hierarchically nested states`.
  void costate<CO extends State>(
    BuildState<CO> buildState,
  ) {
    _stateDefinition.addCoState(buildState);
  }

  void _checkHasNoNullChoices<E extends Event>(EventChoices<S, E> choices) {
    for (var choice in choices.eventChoices) {
      if (choice.condition == null) {
        throw NullChoiceMustBeLastException(choices.eventType);
      }
    }
  }

  /// Sets callback that will be called right after machine enters this State.
  void onEnter(OnEnter onEnter) {
    _stateDefinition.onEnter = onEnter;
  }

  /// Sets callback that will be called right before machine exits this State.
  void onExit(OnExit onExit) {
    _stateDefinition.onExit = onExit;
  }

  /// Use [transitionTo] from within an [EventHandler] to set the
  /// desired [toState] and the [sideEffect] that should be called
  /// when the transition is triggered.
  /// Calling [transitionTo] does NOT immediately change the FSM's state
  /// but rather returns the desired [S] which is then transitioned
  /// into once the [EventHandler] returns.
  /// The [sideEffect] callback is called after the [fromState]'s [onExit]
  /// method is called, but before the [toState]'s [onEntry] method is called.
  /// ```dart
  /// ..state<MobileNoAcquired>((builder) => builder
  ///   ..on<UserFound>((state, event) => builder.transitionTo(Login()), sideEffect: )
  /// ```
  Future<Transition> transitionTo<TOSTATE extends State>({SideEffect sideEffect}) async =>
      createTransition(TOSTATE, sideEffect: sideEffect);

  StateDefinition build() => _stateDefinition;

  void initialState(State initialState) {}
}
