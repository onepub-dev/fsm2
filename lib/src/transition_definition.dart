
import 'graph.dart';
import 'state_definition.dart';
import 'transition.dart';
import 'types.dart';

/// Defines FSM transition: the change from one state to another.
abstract class TransitionDefinition // <S extends State, E extends Event>
{
  Type fromState;
  StateDefinition<State> fromStateDefinition;
  Type eventType;

  /// The transition returned by the [EventHandler].
  final Transition _transition;
  TransitionDefinition._internal(this.fromState, this.fromStateDefinition, this.eventType, this._transition);

  Future<Type> get toState async => (await _transition).toState;

  Future<Transition> trigger(Graph graph, Event event);
}

/// Valid transition meaning that machine goes from [fromState]
/// to [toState]. Transition is caused by [event].
///
/// It contains optional [sideEffect].
class ValidTransitionDefinition extends TransitionDefinition {
  ValidTransitionDefinition(
    Type fromState,
    StateDefinition fromStateDefinition,
    Type eventType,
    Transition transition,
  ) : super._internal(fromState, fromStateDefinition, eventType, transition);

  @override
  Future<Transition> trigger(Graph graph, Event event) async {
    fromStateDefinition?.onExit(fromState, event);

    var transition = (await _transition);

    if (transition.sideEffect != null) transition.sideEffect();

    var toStateDefinition = graph.stateDefinitions[(await toState).runtimeType];

    toStateDefinition?.onEnter(transition.toState, event);

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
  NoOpTransitionDefinition(Type fromState, StateDefinition fromStateDefinition, Type eventType)
      : super._internal(fromState, fromStateDefinition, eventType, createTransition(fromState));
  @override
  Future<Transition> trigger(Graph graph, Event event) {
    return Future.value(_transition);
  }
}

