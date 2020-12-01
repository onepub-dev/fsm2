import 'dart:io';

import 'package:fsm2/src/state_definition.dart';
import 'package:fsm2/src/transitions/fork_transition.dart';
import 'package:fsm2/src/transitions/join_transition.dart';
import 'package:fsm2/src/transitions/on_transition.dart';
import 'package:fsm2/src/transitions/transition_definition.dart';
import 'package:fsm2/src/types.dart';

enum SMCStateType { root, coregion, region, fork, join, simple }

class SMCState {
  SMCState parent;
  String name;
  String label;
  SMCStateType type;

  /// for a region one of its child are the initial state.
  String initialChildState;
  List<SMCTransition> transitions = <SMCTransition>[];
  List<SMCState> children = <SMCState>[];

  SMCState({this.name, this.type});

  ///
  /// Build the SMSState tree
  ///
  SMCState.build(this.parent, StateDefinition<State> sd) {
    if (sd.isLeaf) {
      name = sd.stateType.toString();
      label = name;
      type = SMCStateType.simple;
    } else {
      if (sd.isCoRegion) {
        name = '${sd.stateType.toString()}.parallel';
        label = '${sd.stateType.toString()}';
        type = SMCStateType.coregion;
      } else {
        name = '${sd.stateType.toString()}';
        label = name;
        type = SMCStateType.region;
        initialChildState = sd.initialState.toString();
      }
      for (var child in sd.childStateDefinitions) {
        children.add(SMCState.build(this, child));
      }
    }
    for (var transition in sd.getTransitions(includeInherited: false)) {
      transitions.addAll(SMCTransition.build(this, transition));
    }
    // remove duplicate psuedo states
    transitions = transitions.toSet().toList();
  }

  void addChild(SMCState child) {
    children.add(child);
  }

  ///
  /// write out the file.
  ///
  void write(RandomAccessFile raf, int level) {
    /// we don't write out the name of the VirtualRoot
    if (type != SMCStateType.root) {
      /// version
      if (name == label || label == null) {
        iwrite(raf, level, name);
      } else {
        iwrite(raf, level, '$name [label="$label"]');
      }
    }

    if (hasBody()) {
      iwrite(raf, 0, ' {\n');
    }

    /// write out child states.
    for (var child in children) {
      child.write(raf, level + 1);
      if (child != children.last) iwrite(raf, 0, ',\n');
    }

    if (children.isNotEmpty) raf.writeStringSync(';\n');

    /// Write out the initial state if this isn't a leaf
    if (initialChildState != null) {
      iwrite(raf, 0, '${initialChildState}.initial => $initialChildState;\n');
    }

    /// write out child transitions
    for (var transition in transitions) {
      transition.write(raf, level + 1);

      iwrite(raf, 0, ';\n');
    }

    if (hasBody()) {
      iwrite(raf, level, '}');
    }
  }

  bool hasBody() =>
      (children.isNotEmpty || transitions.isNotEmpty) &&
      type != SMCStateType.root;
}

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
      owner.parent.transitions.add(smc);

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
        owner.parent.transitions.add(pseudoToState);
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
      parent.parent.transitions.add(smc);

      /// need to create a pseudostate to display the join bar.
      var pseudoToState = SMCTransition();
      pseudoToState.from = ']${transition.targetStates[0].toString()}.Join';
      pseudoToState.to = transition.targetStates[0].toString();
      pseudoToState.label = '';
      parent.parent.transitions.add(pseudoToState);
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

  void write(RandomAccessFile raf, int level) {
    iwrite(raf, level, '$from => $to : $label');
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

String indent(int level) {
  return '\t' * (level - 1);
}

void iwrite(RandomAccessFile raf, int level, String message) {
  raf.writeStringSync('${indent(level)}$message');
}
