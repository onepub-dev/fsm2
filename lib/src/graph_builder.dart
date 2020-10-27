import 'state_definition.dart';

import 'state_builder.dart';
import 'state_machine.dart';
import 'transition.dart';
import 'graph.dart';

/// Builder for FSM.
///
/// Instance of this class is passed to [StateMachine.create] method.
class GraphBuilder {
  State _initialState;
  final Map<Type, StateDefinition> _stateDefinitions = {};
  final List<TransitionListener> _onTransitionListeners = [];

  /// Sets initial State.
  void initialState(State state) => _initialState = state;

  /// Adds State definition.
  void state<S extends State>(
    BuildState<S> buildState,
  ) {
    final builder = StateBuilder<S>(S);
    buildState(builder);
    final definition = builder.build();
    _stateDefinitions[S] = definition;
  }

  /// Sets [listener] that will be called on each transition.
  void onTransition(TransitionListener listener) => _onTransitionListeners.add(listener);

  Graph build() => Graph(_initialState, _stateDefinitions, _onTransitionListeners);
}

typedef BuildGraph = void Function(GraphBuilder);

typedef SideEffect = void Function();
