// part of 'state_definition.dart';

// library state_definition;

// part  'co_region_definition.dart';

import 'package:meta/meta.dart';

import '../transitions/join_transition.dart';
import '../types.dart';
import 'state_definition.dart';

class CoRegionDefinition<S extends State> extends StateDefinition<S> {
  CoRegionDefinition(super.stateType);

  /// List of Events that must be received for the join to trigger.
  /// As we receive each one we set the value to true.
  final expectedJoinEvents = <Type, bool>{};

  /// Marks a Join event as received and returns true if all required
  /// events have been received.
  bool _onReceived(Type event) {
    expectedJoinEvents[event] = true;

    /// true if all events have been received.
    return expectedJoinEvents.values.every((element) => element);
  }

  /// Clean up [expectedJoinEvents] when we exit the coregion.
  @override
  @mustCallSuper
  Future<void> internalOnExit(Type fromState, Event? event) async {
    await super.internalOnExit(fromState, event);
    for (final key in expectedJoinEvents.keys) {
      expectedJoinEvents[key] = false;
    }
  }

  /// default implementation.
  @override
  bool canTrigger(Type event) => _onReceived(event);

  /// There can only be one join target state.
  Type? _joinTargetState;

  final joinTransitions = <JoinTransitionDefinition>[];

  /// The onJoin transitions need to register with the owning coregion
  /// as they can be nested in a substate and we need to know about all of then.
  void registerJoin(JoinTransitionDefinition joinTransitionDefinition) {
    _joinTargetState ??= joinTransitionDefinition.targetStates[0];

    /// All joins for a coregion must target the same state.
    assert(_joinTargetState == joinTransitionDefinition.targetStates[0],
        'unexpected state');

    joinTransitions.add(joinTransitionDefinition);

    expectedJoinEvents[joinTransitionDefinition.triggerEvents[0]] = false;
  }
}
