import 'package:fsm2/src/state_definition.dart';

import '../types.dart';
import 'transition_definition.dart';

/// An [OnTransition] is used to store details
/// of an transition defined by [State.on]
class OnTransition<S extends State, E extends Event, TOSTATE extends State> extends TransitionDefinition<S, E> {
  /// If this [OnTransition] is trigger this will be the new [State]
  /// the FSM. If [toState] is null then there MUST be an [eventHandler]
  /// which will be called to determine the new [State].
  /// Either an [eventHandler] or a [toState] must be passed but not both.
  /// [toState] is set by calling the [on] method against a [State]
  Type toState;

  OnTransition(StateDefinition stateDefinition, GuardCondition<E> condition, this.toState, SideEffect sideEffect)
      : super(stateDefinition, condition: condition, sideEffect: sideEffect);

  @override
  List<Type> get targetStates => [toState];

  @override
  // TODO: implement triggerEvents
  List<Type> get triggerEvents => [E];
}
