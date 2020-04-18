part of 'state_machine.dart';

/// Defines FSM transition: the change from one state to another.
class Transition<STATE, EVENT, SIDE_EFFECT> extends Coproduct2<Valid, Invalid> {
  Transition._(this._value);

  final Union2<Valid<STATE, EVENT, SIDE_EFFECT>, Invalid<STATE, EVENT>> _value;

  Transition.valid(
    STATE fromState,
    EVENT event,
    STATE toState,
    SIDE_EFFECT sideEffect,
  ) : this._(Union2.first(Valid(fromState, event, toState, sideEffect)));

  Transition.invalid(STATE state, EVENT event)
      : this._(Union2.second(Invalid(state, event)));

  @override
  R match<R>(
    R Function(Valid<STATE, EVENT, SIDE_EFFECT>) ifFirst,
    R Function(Invalid<STATE, EVENT>) ifSecond,
  ) =>
      _value.match(ifFirst, ifSecond);
}

/// Valid transition meaning that machine goes from [fromState]
/// to [toState]. Transition is caused by [event].
///
/// It contains optional [sideEffect].
class Valid<STATE, EVENT, SIDE_EFFECT> {
  Valid(this.fromState, this.event, this.toState, this.sideEffect);

  final STATE fromState;
  final EVENT event;
  final STATE toState;
  final SIDE_EFFECT sideEffect;
}

/// Invalid transition called by [event]. Machine stays in [state].
class Invalid<STATE, EVENT> {
  Invalid(this.fromState, this.event);

  final STATE fromState;
  final EVENT event;
}
