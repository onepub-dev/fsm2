import 'state_builder.dart';

import 'graph.dart';
import 'state_definition.dart';
import 'state_machine.dart';

/// Defines FSM transition: the change from one state to another.
abstract class TransitionDefinition {
  State fromState;
  StateDefinition fromStateDefinition;
  Event event;

  /// The transition returned by the [EventHandler].
  final Transition _transition;
  TransitionDefinition._internal(
      this.fromState, this.fromStateDefinition, this.event, this._transition);

  State get toState => _transition.toState;

  Transition trigger(Graph graph);
}

/// Valid transition meaning that machine goes from [fromState]
/// to [toState]. Transition is caused by [event].
///
/// It contains optional [sideEffect].
class ValidTransitionDefinition extends TransitionDefinition {
  ValidTransitionDefinition(
    State fromState,
    StateDefinition fromStateDefinition,
    Event event,
    Transition transition,
  ) : super._internal(fromState, fromStateDefinition, event, transition);

  @override
  Transition trigger(Graph graph) {
    fromStateDefinition.onExit(fromState, event);

    _transition.sideEffect();

    var toStateDefinition = graph.stateDefinitions[toState.runtimeType];

    toStateDefinition.onEnter(_transition.toState, event);

    return _transition;
  }
}

// /// Invalid transition called by [event]. Machine stays in [state].
// class InvalidTransition extends Transition {
//   InvalidTransition(this.fromState, this.event);

//   final State fromState;
//   final Event event;
// }

/// Valid transition called by [event] but no [condition] method
/// evaluated to true so no transition will occur.
/// Machine stays in [state].
class NoOpTransitionDefinition extends TransitionDefinition {
  /// no transition so [fromState] == [toState].
  NoOpTransitionDefinition(
      State fromState, StateDefinition fromStateDefinition, Event event)
      : super._internal(
            fromState, fromStateDefinition, event, createTransition(fromState));
  @override
  Transition trigger(Graph graph) {
    return _transition;
  }
}

typedef TransitionListener = void Function(TransitionDefinition);
typedef EventHandler<S extends State, E extends Event> = Transition Function(
    S s, E e);
