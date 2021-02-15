import 'package:fsm2/src/transitions/fork_transition.dart';
import 'package:fsm2/src/transitions/on_transition.dart';

import '../definitions/state_definition.dart';
import '../exceptions.dart';
import '../state_machine.dart';
import '../transitions/join_transition.dart';
import '../types.dart';
import 'fork_builder.dart';
import 'graph_builder.dart';

/// State builder.
///
/// Instance of this class is passed to [GraphBuilder.state] method.
class StateBuilder<S extends State> {
  final StateDefinition<S> _stateDefinition;

  /// The initial state for the substate
  /// If there are no child states then this is just 'this'.
  Type _initialState;

  StateBuilder(StateDefinition parent, this._stateDefinition) {
    _stateDefinition.setParent(parent);
  }

  /// Places a page break into the export file rendering all nested
  /// states on a new page.
  void get pageBreak => _stateDefinition.pageBreak = true;

  /// Statically declares a transition that will occur when Event of type [E]
  /// is sent to machine via [StateMachine.applyEvent] method.
  ///
  ///
  /// ```dart
  /// ..state<MobileNoAcquired>((builder) => builder
  ///   ..on<OnUserFound, LoggedIn>())
  /// ```
  ///
  /// The [condition] argument implements the UML concept a 'guard condition' and
  /// allows you to register multiple transitions for a single Event.
  /// Guard conditions allow you to implement a UML 'Choice psuedostate'.
  /// When the Event is fired each transition will be evaluated in the order
  /// they are added to the State.
  /// The first transition whose guard [condition] method returns true will be triggered, any later
  /// conditions will not be evaluated.
  ///
  /// ```dart
  /// ..state<MobileNoAcquired>((builder) => builder
  ///   ..on<OnUserFound, LoggedIn>(condition: (state, event) => event.subscribed == true))
  ///   ..on<OnUserFound, AskForSubscription>(condition: (state, event) => event.subscribed == false))
  /// ```a
  ///
  /// There MAY be only one transition with a null [condition] and it MUST be the last
  /// transition added to the [S]. A transition with a null [condition] is considered the
  /// 'else' condition in that it fires if none of the transitions with a [condition] evaluate to true.
  ///
  /// An [NullConditionMustBeLastException] will be thrown if you try to register two
  /// transitions for a given Event type with a null [condition] or you try to add a
  /// transition with a non-null [condition] after adding a transition with a null [condition].
  ///
  /// The [conditionLabel] is optional and is only used when exporting. The [conditionLabel] is used
  /// to annotate the transition on the diagram.
  void on<E extends Event, TOSTATE extends State>(
      {GuardCondition<E> condition,
      SideEffect<E> sideEffect,
      String conditionLabel,
      String sideEffectLabel}) {
    final onTransition = OnTransitionDefinition<S, E, TOSTATE>(
        _stateDefinition, condition, TOSTATE, sideEffect,
        conditionLabel: conditionLabel, sideEffectLabel: sideEffectLabel);

    _stateDefinition.addTransition<E>(onTransition);
  }

  /// Adds a nested State definition as per the UML2
  /// specification for `hierarchically nested states`.
  void state<C extends State>(
    BuildState<C> buildState,
  ) {
    addNestedState(_stateDefinition, buildState);
  }

  /// Adds a [coregion] State definition as per the UML2
  /// specification for `orthogonal regions`.
  ///
  /// A [coregion] is where the statemachine can
  /// be in multiple states at the same time.
  ///
  /// The parent state (defined by the call to [coregion])
  /// treats all child states as [coregion]s.
  ///
  /// ```dart
  /// .coregion<MobileAndRegistrationType>((builder) =>
  ///   .state<AcquireMobile> ...
  ///   .state<RegistrationType> ...
  /// ```
  ///
  /// In the above example the [StateMachine] is considered
  /// to be in both the 'AcquireMobile' state and the
  /// 'RegistrationType' state.
  ///
  /// The [coregion] 'MobileAndRegistrationType' is also a parent state
  /// so the machine is said to be in three states at once.
  ///
  void coregion<CO extends State>(BuildCoRegion<CO> buildState) {
    addCoRegion(_stateDefinition, buildState);
  }

  /// Used to enter a co-region by targeting the set of states within the
  /// coregion to transition to.
  void onFork<E extends Event>(BuildFork<E> buildFork,
      {Function(State, E) condition}) {
    final builder = ForkBuilder<E>();
    buildFork(builder);
    final definition = builder.build();

    final choice = ForkTransitionDefinition<S, E>(_stateDefinition, definition);

    _stateDefinition.addTransition(choice);
  }

  /// Adds an event to the set of events that must be triggered to leave the owner[coregion].
  /// Every onJoin in a coregion must target the same external state.
  void onJoin<E extends Event, TOSTATE extends State>(
      {GuardCondition<E> condition, SideEffect sideEffect}) {
    final onTransition = JoinTransitionDefinition<S, E, TOSTATE>(
        _stateDefinition, condition, sideEffect);

    _stateDefinition.addTransition<E>(onTransition);
  }

  /// Sets callback that will be called right after machine enters this State.
  void onEnter(OnEnter onEnter, {String label}) {
    _stateDefinition.onEnter = onEnter;
    _stateDefinition.onEnterLabel = label;
  }

  /// Sets callback that will be called right before machine exits this State.
  void onExit(OnExit onExit, {String label}) {
    _stateDefinition.onExit = onExit;
    _stateDefinition.onExitLabel = label;
  }

  StateDefinition build() {
    if (_stateDefinition.isLeaf) {
      _initialState = _stateDefinition.stateType;
      return _stateDefinition;
    } else {
      /// If no initial state then the first state is the initial state.
      if (_initialState == null &&
          _stateDefinition.childStateDefinitions.isNotEmpty) {
        _initialState = _stateDefinition.childStateDefinitions[0].stateType;
      }

      assert(_initialState != null);
      final sd = _stateDefinition.findStateDefintion(_initialState,
          includeChildren: false);
      if (sd == null) {
        throw InvalidInitialStateException(
            'The initialState $_initialState MUST be a child state of ${_stateDefinition.stateType}.');
      }

      _stateDefinition.initialState = _initialState;

      return _stateDefinition;
    }
  }

  void initialState<I extends State>() {
    _initialState = I;
  }
}
