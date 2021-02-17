// part of 'state_definition.dart';

// library state_definition;

// part  'co_region_definition.dart';

import 'package:fsm2/src/transitions/join_transition.dart';

import '../types.dart';
import 'state_definition.dart';

class CoRegionDefinition<S extends State> extends StateDefinition<S> {
  CoRegionDefinition(Type stateType) : super(stateType);

  /// List of Events that must be received for the join to trigger.
  /// As we receive each one we set the value to true.
  final expectedJoinEvents = <Type, bool>{};

  /// Marks a Join event as received and returns true if all required
  /// events have been received.
  bool _onReceived(Type event) {
    expectedJoinEvents[event] = true;

    /// true if all events have been received.
    return expectedJoinEvents.values.every((element) => element == true);
  }

  /// default implementation.
  @override
  bool canTrigger(Type event) {
    return _onReceived(event);
  }

  /// There can only be one join target state.
  Type? _joinTargetState;

  List<JoinTransitionDefinition<State, Event, State>> joinTransitions =
      <JoinTransitionDefinition>[];

  /// The onJoin transitions need to register with the owning coregion
  /// as they can be nested in a substate and we need to know about all of then.
  void registerJoin(JoinTransitionDefinition joinTransitionDefinition) {
    _joinTargetState ??= joinTransitionDefinition.targetStates[0];

    /// All joins for a coregion must target the same state.
    /// TODO: we could allow multiple targets by creating a map of target states
    /// and the set of events required to trigger them. But that is for later.
    assert(_joinTargetState == joinTransitionDefinition.targetStates[0]);

    joinTransitions.add(joinTransitionDefinition);

    expectedJoinEvents[joinTransitionDefinition.triggerEvents[0]] = false;
  }
}
