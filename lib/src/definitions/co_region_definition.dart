// part of 'state_definition.dart';

// library state_definition;

// part  'co_region_definition.dart';

import 'package:fsm2/src/transitions/join_transition.dart';

import '../types.dart';
import 'state_definition.dart';

class CoRegionDefinition<S extends State> extends StateDefinition<S> {
  CoRegionDefinition(Type stateType) : super(stateType);

  @override
  Future<void> internalOnEnter(Type toState, Event event) async {
    super.internalOnEnter(toState, event);

    //  onJoin cause problems as we actualy need to search child states as OnJoin
    //  can be declared in a child.

    for (final transition in getTransitions(includeInherited: false)) {
      if (transition is JoinTransitionDefinition) {
        transition.reset();
      }
    }
  }

  /// List of Events that must be recieved for the join to trigger.
  /// As we recieve each one we set the value to true.
  final expectedJoinEvents = <Type, bool>{};

  /// Marks a Join event as received and returns true if all required
  /// events have been received.
  bool _onRecieved(Type event) {
    expectedJoinEvents[event] = true;

    /// true if all events have been received.
    return expectedJoinEvents.values.every((element) => element == true);
  }

  /// default implementation.
  @override
  bool canTrigger(Type event) {
    return _onRecieved(event);
  }

  void registerJoin(JoinTransitionDefinition joinTransitionDefinition) {
    expectedJoinEvents[joinTransitionDefinition.triggerEvents[0]] = false;
  }
}
