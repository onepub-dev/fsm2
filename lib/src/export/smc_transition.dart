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

class Branches {
  SMCState from;
  SMCState to;
}

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

    final smcFrom = findSMCState(owner, smcTransition.from);
    final smcTo = findSMCState(owner, smcTransition.to);

    final commonPage = smcFrom.findCommonPage(smcTo);

    if (smcFrom.isSiblingOf(smcTo)) {
      /// siblings will always be on the same page.
      owner.transitions.add(smcTransition);
    }

    /// from is an ancestor of to
    else if (smcFrom.isAncestorOf(smcTo)) {
      if (isOnSamePage(smcFrom, smcTo)) {
        owner.transitions.add(smcTransition);
      } else {
        addEnterTransitions(owner, smcFrom, smcTo, smcTransition);
      }
    }

    /// from is decendant of to
    else if (smcFrom.isDescendantOf(smcTo)) {
      if (commonPage != null) {
        owner.transitions.add(smcTransition);
      } else {
        addExitTransitions(owner, smcFrom, smcTo, smcTransition);
      }
    }
    // from and to must be on different branches of the tree.
    else {
      final branches = smcFrom.findBranchPoint(smcTo);

      final commonPage = branches.from.findCommonPage(branches.to);
      if (commonPage != null) {
        addDirectTransition(
            branches.from, branches.to, commonPage, smcTransition);
      }

      /// the branches will be sibligs so we start
      /// by creating an bridging transition between the
      /// siblines.
      final bridgeTransition = SMCTransition();
      bridgeTransition.from = branches.from.name;
      bridgeTransition.to = branches.to.name;
      owner.transitions.add(smcTransition);

      addExitTransitions(owner, branches.from, smcFrom, smcTransition);
      addEnterTransitions(owner, branches.to, smcTo, smcTransition);
    }
  }

  /// Adds a direct link between to states which MUST be on the same page.
  static void addDirectTransition(
      SMCState from, SMCState to, int commonPage, SMCTransition orginal) {
    final transition = SMCTransition();

    /// generate an exit from the current state
    transition.from = from.name;
    transition.to = genFinalState(transition.from);
    transition.label = orginal.label;

    // WHO is the owner here as I think it controls what page these go on which is possible not the same as the commonPage.
    // Same goes for each of the other tranitions.

    findPageOwner(from, commonPage).transitions.add(transition);
  }

  static void addExitTransitions(SMCState owner, SMCState smcFrom,
      SMCState smcTo, SMCTransition original) {
    final transition = SMCTransition();

    /// generate an exit from the current state
    transition.from = smcFrom.name;
    transition.to = genFinalState(transition.from);
    transition.label = original.label;

    owner.transitions.add(transition);

    /// final state transition on each page up to the target ancestor
    var parent = owner.parent;
    while (parent != smcTo) {
      final transition = SMCTransition();

      /// generate an exit from the current state
      transition.from = parent.name;
      transition.to = genFinalState(transition.from);
      transition.label = original.label;
      if (parent.parent == null) break;
      assert(parent.parent != null);
      parent = parent.parent;

      parent.transitions.add(transition);
    }

    /// add final transtiion to the actual 'to' state
    final finalTransition = SMCTransition();

    /// generate an exit from the current state
    finalTransition.from = parent.name;
    finalTransition.to = smcTo.name;
    finalTransition.label = original.label;
    smcTo.transitions.add(finalTransition);
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

  static bool isOnSamePage(SMCState lhs, SMCState rhs) {
    return
        // !lhs.isStraddleState &&
        //     !rhs.isStraddleState &&
        lhs.pageNo == rhs.pageNo;
  }

  /// True if the [state] is on [page]. If the [state] is a
  /// straddle state then it is considered on the same page if
  /// either the parent or child page is equal to [page].
  static bool isOnPage(SMCState state, int page) {
    return state.pageNo == page ||
        (state.isStraddleState && state.straddleChildPage == page);
  }

  static void addEnterTransitions(SMCState owner, SMCState smcFrom,
      SMCState smcTo, SMCTransition smcTransition) {
    /// On the 'to' page we show a 'initial' transition.
    ///
    var transition = SMCTransition();

    /// generate an init into [smcTo] from its parent
    transition.from = genInitialState(smcTo.name);
    transition.to = smcTo.name;
    transition.label = smcTransition.label;
    smcTo.parent.transitions.add(transition);

    /// Starting from the [smcTo] work our way back up to [smcFrom]
    /// Write an enter transition as we move to each new ancestor page
    var parent = smcTo.parent;
    var currentPageNo = smcTo.pageNo;
    while (currentPageNo > smcFrom.pageNo) {
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

    /// We are back up at the [scmFrom] state so add a
    /// transition from the [scmFrom] state to the
    /// straddle state on this page.
    transition = SMCTransition();

    /// generate an exit from the current state
    transition.from = smcFrom.name;
    transition.to = getStraddleStateForPage(smcTo, smcFrom.pageNo).name;
    transition.label = smcTransition.label;

    /// originally had parent.parent?
    parent.transitions.add(transition);
  }

  /// Finds the first [SMCState] that appears in the page.
  /// i.e. the state closes to the root.
  ///
  /// If there are multiple siblings at the same level we
  /// retrn the first one.
  ///
  /// [start] must be either in the [page] or in a later page (one with a higher no.)
  static SMCState findPageOwner(SMCState start, int page) {
    var parent = start;

    assert(parent.pageNo <= page || isOnPage(parent, page));

    while (!isOnPage(parent, page)) {
      parent = parent.parent;
    }

    if (!parent.isRoot) {}

    return parent;
  }
}
