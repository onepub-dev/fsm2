import 'package:meta/meta.dart';
import 'state_definition.dart';
import 'state_builder.dart';
import 'state_machine.dart';
import 'graph.dart';
import 'types.dart';

/// Builder for FSM.
///
/// Instance of this class is passed to [StateMachine.create] method.
class GraphBuilder {
  Type _initialState;
  final _stateDefinitions = <StateDefinition>[];
  final List<TransitionListener> _onTransitionListeners = [];

  /// Sets initial State.
  void initialState<S extends State>() => _initialState = S;

  /// Adds State definition.
  void state<S extends State>(
    BuildState<S> buildState,
  ) {
    final builder = StateBuilder<S>(S);
    buildState(builder);
    final definition = builder.build();
    _stateDefinitions.add(definition);
  }

  /// Adds coState definition.
  /// A co state is where the statemachine can
  /// have be in two states at the same time.
  /// The parent state (defined by the call to costate)
  /// treats all child states as co states.
  ///
  /// ```dart
  /// .costate<MobileAndRegistrationType>((builder) =>
  ///   .state<AcquireMobile> ...
  ///   .state<RegistrationType> ...
  /// ```
  ///
  /// In the above example the [StateMachine] is considered
  /// to be in both the 'AcquireMobile' state and the
  /// 'RegistrationType' state. The [costate] is also
  /// a parent state and of the states and the [StateMachine]
  /// is also considered to be in the parent costate so in reality
  /// the machine is in three states at once.
  void costate<S extends State>(
    BuildState<S> buildState,
  ) {
    final builder = StateBuilder<S>(S);
    buildState(builder);
    final definition = builder.build();
    _stateDefinitions.add(definition);
  }

  /// Sets [listener] that will be called on each transition.
  void onTransition(TransitionListener listener) => _onTransitionListeners.add(listener);

  Graph build() => Graph(_initialState, _stateDefinitions, _onTransitionListeners);

  @visibleForTesting

  /// returns a shallow copy of the [_stateDefinitions] map.
  List<StateDefinition> get stateDefinitions => List<StateDefinition>.from(_stateDefinitions);
}


