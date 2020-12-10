import 'package:fsm2/src/export/smc_state.dart';
import 'package:fsm2/src/transitions/fork_transition.dart';
import 'package:fsm2/src/transitions/join_transition.dart';
import 'package:fsm2/src/transitions/on_transition.dart';
import 'package:fsm2/src/transitions/transition_definition.dart';
import 'package:tree_iterator/tree_iterator.dart';

import 'package:meta/meta.dart';

import '../state_machine.dart';
import '../types.dart';
import 'exporter.dart';

class SMCTransition {
  /// names are case sensitive.
  static const fork = 'fork';
  static const join = 'join';
  static const finalState = 'final';
  static const initial = 'initial';

  /// The State Type.
  String from;

  /// The State Type.
  String to;
  String toName;
  String label;
  String pseudoState;

  /// A single [TransitionDefinition] can result in multiple transition lines.
  static List<SMCTransition> build(StateMachine stateMachine, SMCState owner,
      TransitionDefinition<Event> transition) {
    final transitions = <SMCTransition>[];

    // fork
    if (transition is ForkTransitionDefinition) {
      final smct = SMCTransition();
      final from = transition.fromStateDefinition.stateType;
      smct.from = from.toString();
      smct.to = genForkState(from);
      smct.label = transition.label;
      // owner.parent.transitions.add(smc);
      expandPageBreaks(stateMachine, owner, smct);

      for (final target in transition.targetStates) {
        // var parent = owner;
        // while (parent.type != SMCStateType.coregion) {
        //   parent = parent.parent;
        // }

        /// need to create a pseudostate to display the fork bar.
        final pseudoToState = SMCTransition();
        pseudoToState.from = smct.to;
        // ignore: unnecessary_string_interpolations
        pseudoToState.to = '${target.toString()}';
        pseudoToState.label = '';
        //owner.parent.transitions.add(pseudoToState);
        expandPageBreaks(stateMachine, owner, pseudoToState);
      }
    }

    /// join
    else if (transition is JoinTransitionDefinition) {
      /// joins are added to the coregion ancestor
      var parent = owner;
      while (parent.type != SMCStateType.coregion) {
        parent = parent.parent;
      }
      final smct = SMCTransition();
      smct.from = transition.fromStateDefinition.stateType.toString();
      smct.to = genJoinState(transition.targetStates[0]);
      smct.label = transition.label;
      // smc.pseudoState = ']${transition.targetStates[0].toString()}.Join';
      // parent.parent.transitions.add(smc);
      expandPageBreaks(stateMachine, parent, smct);

      /// need to create a pseudostate to display the join bar.
      final pseudoToState = SMCTransition();
      pseudoToState.from = genJoinState(transition.targetStates[0]);
      pseudoToState.to = transition.targetStates[0].toString();
      pseudoToState.label = '';
      // parent.parent.transitions.add(pseudoToState);
      expandPageBreaks(stateMachine, parent, pseudoToState);
    }

    // on
    else //  (transition is OnTransition)
    {
      assert(transition is OnTransitionDefinition);
      for (final trigger in transition.triggerEvents) {
        final smct = SMCTransition();
        smct.from = owner.name;
        final target = transition.targetStates[0];
        // ignore: unnecessary_parenthesis
        smct.to = (target == FinalState
            ? genFinalState(owner.name)
            : target.toString());
        smct.label = transition.labelForTrigger(trigger);

        /// The final transition is always placed outside the substate.
        if (target == FinalState) {
          expandPageBreaks(stateMachine, owner.parent, smct);
        } else {
          expandPageBreaks(stateMachine, owner, smct);
        }
      }
    }
    return transitions;
  }

  static String genFinalState(String name) {
    return ']$name.$finalState';
  }

  static String genInitialState(String name) {
    return ']$name.$initial';
  }

  static String genForkState(Type stateType) {
    return ']$stateType.$fork';
  }

  static String genJoinState(Type stateType) {
    return ']$stateType.$join';
  }

  void write(Exporter exporter, {@required int page, @required int indent}) {
    if (label != null && label.isNotEmpty) {
      exporter.write('$from => $to : $label;', page: page, indent: indent);
    } else {
      exporter.write('$from => $to ;', page: page, indent: indent);
    }
  }

  @override
  bool operator ==(covariant SMCTransition other) {
    return from == other.from && to == other.to && label == other.label;
  }

  @override
  int get hashCode {
    return from.hashCode + to.hashCode + (label ?? '').hashCode;
  }

  /// As we have page breaks the target state may no always be on the current page.
  /// We may also end up with a single transition having multiple targets:
  ///  The intended target which appears on a different page.
  ///
  ///
  ///  - is the transition is to a state on the same page
  ///     - no change to transition
  ///
  /// - is the transition to a state on an ancestor page
  ///  - 'n' transition must be show.
  ///  - one from the child state indication an exit from the current page/sub state
  ///  - one for each intermediate page showing an exit from the 'top' state on the page
  ///  - one from the parent state to the intended target (on the intended targets page)
  ///  - what symbol does UML2 to show a transition that exits the current sub state?

  /// - is the transition 'to' a state on a child page
  ///    - on the child page we show an 'initial transition' into the child state
  ///    - we then transition up the tree from the child state to the parent
  ///      adding an initial transition to each state that stradles a page boundary.
  ///
  ///    - from the 'pages top state'.
  ///
  /// Owner and from will be the same state unless from is a psuedo state (fork/join).
  ///
  static void expandPageBreaks(
      StateMachine stateMachine, SMCState owner, SMCTransition smcTransition) {
    // final from = stateMachine.findStateDefinitionFromString(smcTransition.from);
    // final to = stateMachine.findStateDefinitionFromString(smcTransition.to);

    final scmFrom = findSMCState(owner, smcTransition.from);
    final scmTo = findSMCState(owner, smcTransition.to);

    /// Is the transition to/from on the same page
    if (scmFrom.pageNo == scmTo.pageNo) {
      owner.transitions.add(smcTransition);
    }

    /// Is the transition 'to' an ancestor state
    else if (scmFrom.pageNo > scmTo.pageNo) {
      final transition = SMCTransition();

      /// generate an exit from the current state
      transition.from = scmFrom.name;
      transition.to = genFinalState(transition.from);
      transition.label = smcTransition.label;

      owner.transitions.add(transition);

      /// final state transition on each page up to the target ancestor
      var parent = owner.parent;
      while (parent != scmTo) {
        final transition = SMCTransition();

        /// generate an exit from the current state
        transition.from = parent.name;
        transition.to = genFinalState(transition.from);
        transition.label = smcTransition.label;

        parent.parent.transitions.add(transition);
        parent = parent.parent;
      }

      /// add final transtiion to the actual 'to' state
      final finalTransition = SMCTransition();

      /// generate an exit from the current state
      finalTransition.from = parent.name;
      finalTransition.to = scmTo.name;
      finalTransition.label = smcTransition.label;
      scmTo.transitions.add(finalTransition);
    }

    /// The transition is 'to' a child state
    else {
      /// On the 'to' page we show a 'initial' transition.
      ///
      var transition = SMCTransition();

      /// generate an init into the current state
      transition.from = genInitialState(scmTo.name);
      transition.to = scmTo.name;
      transition.label = smcTransition.label;
      scmTo.parent.transitions.add(transition);

      /// Write a transition as we move to each new ancestor page
      var parent = scmTo.parent;
      var currentPageNo = scmTo.pageNo;
      while (currentPageNo > scmFrom.pageNo) {
        if (currentPageNo != parent.pageNo) {
          // we are on a new page so show an init transition.
          final transition = SMCTransition();

          /// generate an init into the current state
          if (!parent.parent.isRoot) {
            transition.from = genInitialState(parent.name);
            transition.to = parent.name;
            transition.label = smcTransition.label;
            parent.parent.transitions.add(transition);
          }
        }
        parent = parent.parent;
        currentPageNo = parent.pageNo;
      }

      /// We are back up ato the 'from' state so add a
      /// transition from the 'from' state to the
      /// straddle state on this page.
      transition = SMCTransition();

      /// generate an exit from the current state
      transition.from = scmFrom.name;
      transition.to = getStraddleStateForPage(scmTo, scmFrom.pageNo).name;
      transition.label = smcTransition.label;

      /// originally had parent.parent?
      parent.transitions.add(transition);
    }
  }

  /// Find the SMCState for the name.
  /// If the name is for a pseudo state then we return the state
  /// that the pseudo state name is based on.
  static SMCState findSMCState(SMCState owner, String name) {
    /// traverse the tree back up to the virtual root and then search down from there
    /// until we find the matching sd.
    final root = getRoot(owner);

    var matcher = name;
    if (name.startsWith(']')) {
      /// psudo names are of the form ']state.type]
      /// and we just want the state name.
      matcher = name.split('.')[0].substring(1);
    }

    return findInTree<SMCState>(
        root, (node) => node.children, (child) => child.name == matcher);
  }

  /// Find the root of the SMCState tree.
  /// TODO: consider passing done the root from the exporter.
  static SMCState getRoot(SMCState owner) {
    var parent = owner.parent;

    while (parent.type != SMCStateType.root) {
      parent = parent.parent;
    }
    return parent;
  }

  /// Work our way up the tree from the given [child] until we find
  /// the exit straddle state on [targetPageNo].
  /// Each page can have an 'enter' straddle state and an 'exit' straddle state.
  /// The 'exit' straddle state is the straddle state that takes us to a child page.
  /// The 'enter' straddle state is the straddle state that takes to a parent page.
  static SMCState getStraddleStateForPage(SMCState child, int targetPageNo) {
    var current = child;
    while (current.pageNo != targetPageNo) {
      current = current.parent;
    }

    /// The first state we see on a new page should be a straddle state.
    assert(current.isStraddleState);

    return current;
  }
}
