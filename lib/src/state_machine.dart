import 'package:dfunc/dfunc.dart';

class StateMachine<STATE, EVENT, SIDE_EFFECT> {
  StateMachine._(this._graph) : state = _graph.initialState;

  Transition<STATE, EVENT, SIDE_EFFECT> transition(EVENT event) {
    final fromState = state;
    final transition = getTransition(fromState, event);
    transition.match((v) => state = v.toState, ignore);
    return transition;
  }

  final Graph<STATE, EVENT, SIDE_EFFECT> _graph;

  STATE state;

  factory StateMachine.create(
      Function(GraphBuilder<STATE, EVENT, SIDE_EFFECT>) buildGraph) {
    final graphBuilder = GraphBuilder<STATE, EVENT, SIDE_EFFECT>._();
    buildGraph(graphBuilder);
    return StateMachine._(graphBuilder._build());
  }

  Transition<STATE, EVENT, SIDE_EFFECT> getTransition(
      STATE state, EVENT event) {
    final createTransitionTo = _graph
        .stateDefinitions[state.runtimeType].transitions[event.runtimeType];
    if (createTransitionTo == null) {
      return Transition.invalid(Invalid(state, event));
    }
    final transition = createTransitionTo(state, event);
    return Transition.valid(Valid(
        state, event, transition.toState, Optional.of(transition.sideEffect)));
  }
}

typedef CreateTransitionTo<STATE, EVENT, SIDE_EFFECT>
    = TransitionTo<STATE, SIDE_EFFECT> Function(STATE s, EVENT e);

typedef BuildState<STATE, EVENT, SIDE_EFFECT> = Function(
    StateBuilder<STATE, EVENT, SIDE_EFFECT>);

class GraphBuilder<STATE, EVENT, SIDE_EFFECT> {
  GraphBuilder._();

  STATE _initialState;
  final Map<Type, State<STATE, EVENT, SIDE_EFFECT>> _stateDefinitions = {};
  final List<void Function(Transition<STATE, EVENT, SIDE_EFFECT>)>
      _onTransitionListeners = [];

  void initialState(STATE state) => _initialState = state;

  void state<S extends STATE>(
      BuildState<STATE, EVENT, SIDE_EFFECT> buildState) {
    final builder = StateBuilder<STATE, EVENT, SIDE_EFFECT>();
    buildState(builder);
    final definition = builder.build();
    _stateDefinitions[S] = definition;
  }

  Graph<STATE, EVENT, SIDE_EFFECT> _build() =>
      Graph(_initialState, _stateDefinitions, _onTransitionListeners);
}

class StateBuilder<STATE, EVENT, SIDE_EFFECT> {
  final State<STATE, EVENT, SIDE_EFFECT> _stateDefinition = State._();

  void on<E extends EVENT>(
      CreateTransitionTo<STATE, EVENT, SIDE_EFFECT> createTransitionTo) {
    _stateDefinition.transitions[E] = createTransitionTo;
  }

  State<STATE, EVENT, SIDE_EFFECT> build() => _stateDefinition;
}

class Graph<STATE, EVENT, SIDE_EFFECT> {
  Graph(this.initialState, this.stateDefinitions, this.onTransitionListeners);

  final STATE initialState;
  final Map<Type, State<STATE, EVENT, SIDE_EFFECT>> stateDefinitions;
  final List<void Function(Transition<STATE, EVENT, SIDE_EFFECT>)>
      onTransitionListeners;
}

class State<STATE, EVENT, SIDE_EFFECT> {
  State._();

  final Map<Type, TransitionTo<STATE, SIDE_EFFECT> Function(STATE, EVENT)>
      transitions = {};
}

class TransitionTo<STATE, SIDE_EFFECT> {
  TransitionTo(this.toState, [this.sideEffect]);

  final STATE toState;
  final SIDE_EFFECT sideEffect;
}

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
