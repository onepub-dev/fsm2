import 'package:fsm2/src/export/smc_state.dart';
import 'package:fsm2/src/transitions/fork_transition.dart';
import 'package:fsm2/src/transitions/join_transition.dart';
import 'package:fsm2/src/transitions/on_transition.dart';
import 'package:fsm2/src/transitions/transition_definition.dart';
import 'package:meta/meta.dart';

import '../types.dart';
import 'exporter.dart';

class SMCTransition {
  String from;
  String to;
  String label;
  String pseudoState;

  /// A single [TransitionDefinition] can result in multiple transition lines.
  static List<SMCTransition> build(
      SMCState owner, TransitionDefinition<Event> transition) {
    var transitions = <SMCTransition>[];

    // fork
    if (transition is ForkTransitionDefinition) {
      var smc = SMCTransition();
      var from = transition.fromStateDefinition.stateType.toString();
      smc.from = from;
      smc.to = ']$from.Fork';
      smc.label = transition.triggerEvents[0].toString();
      // owner.parent.transitions.add(smc);
      owner.transitions.add(smc);

      for (var target in transition.targetStates) {
        // var parent = owner;
        // while (parent.type != SMCStateType.coregion) {
        //   parent = parent.parent;
        // }

        /// need to create a pseudostate to display the fork bar.
        var pseudoToState = SMCTransition();
        pseudoToState.from = smc.to;
        pseudoToState.to = '${target.toString()}';
        pseudoToState.label = '';
        //owner.parent.transitions.add(pseudoToState);
        owner.transitions.add(pseudoToState);
      }
    }

    /// join
    else if (transition is JoinTransitionDefinition) {
      /// joins are added to the coregion ancestor
      var parent = owner;
      while (parent.type != SMCStateType.coregion) {
        parent = parent.parent;
      }
      var smc = SMCTransition();
      smc.from = transition.fromStateDefinition.stateType.toString();
      smc.to =
          ']${transition.targetStates[0].toString()}.Join'; // transition.targetStates[0].toString();
      smc.label = transition.triggerEvents[0].toString();
      // smc.pseudoState = ']${transition.targetStates[0].toString()}.Join';
      // parent.parent.transitions.add(smc);
      parent.transitions.add(smc);

      /// need to create a pseudostate to display the join bar.
      var pseudoToState = SMCTransition();
      pseudoToState.from = ']${transition.targetStates[0].toString()}.Join';
      pseudoToState.to = transition.targetStates[0].toString();
      pseudoToState.label = '';
      // parent.parent.transitions.add(pseudoToState);
      parent.transitions.add(pseudoToState);
    }
    // on
    else //  (transition is OnTransition)
    {
      assert(transition is OnTransitionDefinition);
      for (var trigger in transition.triggerEvents) {
        var smc = SMCTransition();
        smc.from = owner.name;
        var target = transition.targetStates[0];
        smc.to =
            (target == FinalState ? '${owner.name}.final' : target.toString());
        smc.label = (trigger ?? '').toString();

        /// The final transition is always placed outside the substate.
        if (target == FinalState) {
          owner.parent.transitions.add(smc);
        } else {
          transitions.add(smc);
        }
      }
    }
    return transitions;
  }

  void write(Exporter exporter, {@required int page, @required int indent}) {
    exporter.write('$from => $to : $label;', page: page, indent: indent);
  }

  @override
  bool operator ==(covariant SMCTransition other) {
    return from == other.from && to == other.to && label == other.label;
  }

  @override
  int get hashCode {
    return from.hashCode + to.hashCode + (label ?? '').hashCode;
  }
}
