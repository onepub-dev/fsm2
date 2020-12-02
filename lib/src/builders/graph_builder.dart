import 'package:meta/meta.dart';
import '../definitions/co_region_definition.dart';
import '../definitions/state_definition.dart';
import 'state_builder.dart';
import '../state_machine.dart';
import '../graph.dart';
import '../types.dart';
import '../virtual_root.dart';

/// Builder for FSM.
///
/// Instance of this class is passed to [StateMachine.create] method.
class GraphBuilder {
  Type _initialState;
  final _stateDefinitions = <StateDefinition>[];
  final List<TransitionListener> _onTransitionListeners = [];
  final StateDefinition<VirtualRoot> virtualRoot =
      StateDefinition<VirtualRoot>(VirtualRoot);

  String _initialStateLabel;

  /// Sets initial State.
  void initialState<S extends State>({String label}) {
    _initialState = S;
    _initialStateLabel = label ?? _initialState.toString();
  }

  /// Adds State definition.
  void state<S extends State>(
    BuildState<S> buildState,
  ) {
    final builder = StateBuilder<S>(S, virtualRoot, StateDefinition(S));
    buildState(builder);
    final definition = builder.build();

    _stateDefinitions.add(definition);
  }

  /// Adds [coregion]] definition.
  /// A [coregion] is where the statemachine can
  /// have be in two states at the same time.
  /// The parent state (defined by the call to [coregion])
  /// treats all child states as [coregion]].
  ///
  /// ```dart
  /// .coregion<MobileAndRegistrationType>((builder) =>
  ///   .state<AcquireMobile> ...
  ///   .state<RegistrationType> ...
  /// ```
  ///
  /// In the above example the [StateMachine] is considered
  /// to be in both the 'AcquireMobile' state and the
  /// 'RegistrationType' state. The [coregion] is also
  /// a parent state and of the states and the [StateMachine]
  /// is also considered to be in the parent [coregion] so in reality
  /// the machine is in three states at once.
  void coregion<S extends State>(
    BuildState<S> buildState,
  ) {
    final builder = StateBuilder<S>(
        S, StateDefinition(VirtualRoot), CoRegionDefinition(VirtualRoot));
    buildState(builder);
    final definition = builder.build();
    _stateDefinitions.add(definition);
  }

  /// Sets [listener] that will be called on each transition.
  void onTransition(TransitionListener listener) =>
      _onTransitionListeners.add(listener);

  Graph build() => Graph(virtualRoot, _initialState, _stateDefinitions,
      _onTransitionListeners, _initialStateLabel);

  @visibleForTesting

  /// returns a shallow copy of the [_stateDefinitions] map.
  List<StateDefinition> get stateDefinitions =>
      List<StateDefinition>.from(_stateDefinitions);
}
