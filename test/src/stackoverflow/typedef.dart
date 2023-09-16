// import 'dart:async';

// class Event {}

// class OnBadAir extends Event {
//   OnBadAir(this.quality);
//   int quality;
// }

// class State {}

// class FanOn extends State {}

// class FanOff extends State {}

// typedef GuardCondition<E extends Event> = bool Function(E event);
// bool noopGuardCondition(Event v) => true;

// class _QueuedEvent {
//   _QueuedEvent(this.event);
//   Event event;
// }

// class StateDefinition<S extends State> {
// //  List<TransitionDefinition> transitions = <TransitionDefinition>[];
//   final Map<Type, List<TransitionDefinition>> _eventTranstionsMap = {};

//   void addTransition<FROMSTATE extends State, E extends Event,
//           TOSTATE extends State>(
//       TransitionDefinition<FROMSTATE, E, TOSTATE> transitionDefinition) {
//     var transitionDefinitions = _eventTranstionsMap[E];
//     transitionDefinitions ??= <TransitionDefinition<FROMSTATE, E
//, TOSTATE>>[];

//     if (transitionDefinition.condition == noopGuardCondition) {
//       print('no-op');
//     }

//     transitionDefinitions.add(transitionDefinition);
//     _eventTranstionsMap[E] = transitionDefinitions;
//   }
// }

// class StateMachine {
//   final _eventQueue = <_QueuedEvent>[];

//   // final List<StateDefinition> _stateDefinitions = <StateDefinition>[];

//   void on<E extends Event, FROMSTATE extends State, TOSTATE extends State>(
//       {GuardCondition<E> condition = noopGuardCondition}) {
//     // final onTransition = TransitionDefinition<FROMSTATE, E, TOSTATE>(
//     //   _stateDefinition,
//     //   condition,
//     //   TOSTATE,
//     // );

//     // _stateDefinition.addTransition<E>(onTransition);
//   }

//   void queue<E extends Event>(E event) {
//     final qe = _QueuedEvent(event);
//     _eventQueue.add(qe);

//     /// process the event on a microtask.
//     Future.delayed(Duration.zero, _dispatch);
//   }

//   /// dequeue the next event and transition it.
//   Future<void> _dispatch() async {
//     assert(_eventQueue.isNotEmpty, 'The event queue is in an invalid state');
//     final event = _eventQueue.first;

//     /// crashes here.
//     // if (td.condition(event.event as E)) {
//     //   print('it worked');
//     // }
//   }
// }

// class TransitionDefinition<FROMSTATE extends State, E extends Event,
//     TOSTATE extends State> {
//   TransitionDefinition(this.fromStateDefinition, this.toState,
//       {this.condition = noopGuardCondition});
//   final GuardCondition<E> condition;

//   final StateDefinition<State> fromStateDefinition;
//   Type toState;
// }

// void main() async {
//   // final fork = Fork<OnBadAir>(
//   //     TransitionDefinition<OnBadAir>(condition: (e) => e.quality < 10))
//   //   ..queue(OnBadAir(10));

//   // await fork._dispatch();
// }
