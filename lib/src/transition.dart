// /// When a user calls [StateBuilder.transitionTo]
// /// Used the Event  [StateBuilder] dsl when  [ is
// /// called. The
// class Transition<S extends State> {
//   Transition._internal(this.toState, {this.sideEffect});

//   final Type toState;
//   final SideEffect sideEffect;
// }

// /// global function to avoid contaminating the public api with a ctor
// /// from Transaction.
// /// [finalState] is the [StateOfMind] of the FSM after the transition has
// /// been applied.
// Transition createTransition(Type finalState, {SideEffect sideEffect}) {
//   var transition = Transition._internal(finalState, sideEffect: sideEffect);

//   return transition;
// }
