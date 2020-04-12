import 'package:dfunc/dfunc.dart';

class Transition<STATE, EVENT, SIDE_EFFECT> extends Coproduct2<Valid, Invalid> {
  Transition._(this._value);

  final Union2<Valid<STATE, EVENT, SIDE_EFFECT>, Invalid<STATE, EVENT>> _value;

  Transition.valid(Valid<STATE, EVENT, SIDE_EFFECT> value)
      : this._(Union2.first(value));

  Transition.invalid(Invalid<STATE, EVENT> value)
      : this._(Union2.second(value));

  @override
  R match<R>(
    R Function(Valid<STATE, EVENT, SIDE_EFFECT>) ifFirst,
    R Function(Invalid<STATE, EVENT>) ifSecond,
  ) =>
      _value.match(ifFirst, ifSecond);
}

class Valid<STATE, EVENT, SIDE_EFFECT> {
  Valid(this.fromState, this.event, this.toState, this.sideEffect);

  final STATE fromState;
  final EVENT event;
  final STATE toState;
  final Optional<SIDE_EFFECT> sideEffect;
}

class Invalid<STATE, EVENT> {
  Invalid(this.fromState, this.event);

  final STATE fromState;
  final EVENT event;
}
