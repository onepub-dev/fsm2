
import 'types.dart';

/// When a user calls [StateBuilder.transitionTo]
/// Used the Event  [StateBuilder] dsl when  [ is
/// called. The
class Transition<S extends State> {
  Transition._internal(this.toState, {this.sideEffect});

  final Type toState;
  final SideEffect sideEffect;
}

/// global function to avoid contaminating the public api with a ctor
/// from Transaction.
Transition createTransition(Type toState, {SideEffect sideEffect}) {
  var transition = Transition._internal(toState, sideEffect: sideEffect);

  return transition;
}
