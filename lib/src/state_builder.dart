import 'package:fsm/src/event_choices.dart';
import 'package:fsm/src/graph_builder.dart';
import 'package:fsm/src/state_machine.dart';
import 'package:fsm/src/transition.dart';

import 'exceptions.dart';
import 'state_definition.dart';

/// State builder.
///
/// Instance of this class is passed to [GraphBuilder.State] method.
class StateBuilder<S extends State> {
  final StateDefinition _stateDefinition;

  StateBuilder(Type stateType) : _stateDefinition = StateDefinition<S>(stateType);

  /// Sets transition that will be called when Event of type [E]
  /// is sent to machine via [StateMachine.transition] method.
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
  /// The [condition] argument allows you to register multiple transitions for a
  /// single Event.
  /// When the Event is fired each transition will be evaluated in the order
  /// they are added to the State.
  /// The first transition whose [condition] method returns true will be triggered, any additional
  /// choices will not be evaluated.
  ///
  /// ```dart
  /// ..state<MobileNoAcquired>((builder) => builder
  ///   ..on<UserFound>((state, event) => builder.transitionTo(Login())
  ///       , choice: (state, event) => event.subscribed == true))
  ///   ..on<UserFound>((state, event) => builder.transitionTo(AskForSubscription())
  ///       , choice: (state, event) => event.subscribed == false))
  /// ```
  ///
  /// There MAY be only one transition with a null [condition] and it MUST be the last
  /// transition added to the [State].
  ///
  /// An [NullChoiceMustBeLastException] will be thrown if you try to register two
  /// transitions for a given Event type with a null [condition] or you try to add a
  /// transition with a non-null [condition] after adding a transition with a null [condition].
  void on<E extends Event>(EventHandler<S, E> eventHandler, {Condition<S, E> condition}) {
    //   _StateDefinition.transitions[E] = (State s, Event e) => createTransitionTo(s, e);

    var choices = _stateDefinition.transitions[E];
    if (choices == null) {
      choices = EventChoices<S, E>();
      choices.eventType = E;
    }

    var eventChoice = EventChoice<S, E>();

    eventChoice.condition = condition;
    eventChoice.requestTransition = eventHandler;

    /// there may only be one transition for a given Event with a null choice function
    /// and it must be the last transition added.
    _checkHasNoNullChoices(choices);

    choices.eventChoices.add(eventChoice);

    _stateDefinition.transitions[E] = choices;
  }

  void _checkHasNoNullChoices(EventChoices choices) {
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
  /// but rather returns the desired [State] which is then transitioned
  /// into once the [EventHandler] returns.
  /// The [sideEffect] callback is called after the [fromState]'s [onExit]
  /// method is called, but before the [toState]'s [onEntry] method is called.
  /// ```dart
  /// ..state<MobileNoAcquired>((builder) => builder
  ///   ..on<UserFound>((state, event) => builder.transitionTo(Login()), sideEffect: )
  /// ```
  Transition transitionTo(State toState, {SideEffect sideEffect}) =>
      Transition._internal(toState, sideEffect: sideEffect);

  StateDefinition build() => _stateDefinition;
}

/// When a user calls [StateBuilder.transitionTo]
/// Used the Event  [StateBuilder] dsl when  [ is
/// called. The
class Transition {
  Transition._internal(this.toState, {this.sideEffect});

  final State toState;
  final SideEffect sideEffect;
}

/// global function to avoid contaimating the public api with a ctor
/// from Transaction.
Transition createTransition(State toState) {
  var transition = Transition._internal(toState);

  return transition;
}

/// The builder.
typedef BuildState<S extends State> = void Function(StateBuilder<S>);
