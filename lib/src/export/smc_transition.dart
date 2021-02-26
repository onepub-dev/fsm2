import 'package:fsm2/src/export/smc_pseudo_state.dart';
import 'package:fsm2/src/export/smc_state.dart';
import 'package:fsm2/src/transitions/fork_transition.dart';
import 'package:fsm2/src/transitions/join_transition.dart';
import 'package:fsm2/src/transitions/on_transition.dart';
import 'package:fsm2/src/transitions/transition_definition.dart';
import 'package:fsm2/src/virtual_root.dart';
import 'package:fsm2/src/visualise/smcat_file.dart';
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

  /// The State Type.
  SMCState from;

  /// The State Type.
  SMCState to;
  String label;
  String pseudoState;

  SMCTransition({@required this.from, @required this.to})
      : assert(from.name != to.name);

  /// A single [TransitionDefinition] can result in multiple transition lines.
  static List<SMCTransition> build(StateMachine stateMachine, SMCState owner,
      TransitionDefinition<Event> transition) {
    final transitions = <SMCTransition>[];

    // fork
    if (transition is ForkTransitionDefinition) {
      /// Create a transition from [from] state to a generated pseudo fork state.
      final smct = SMCTransition(
          from: findSMCState(owner, transition.fromStateDefinition.stateType),
          to: genForkState(owner, transition.fromStateDefinition.stateType));
      smct.label = transition.label;
      // owner.parent.transitions.add(smc);
      expandPageBreaks(stateMachine, owner, smct);

      /// Wire the fork psuedo state to each target state
      for (final target in transition.targetStates) {
        final pseudoToState =
            SMCTransition(from: smct.to, to: findSMCState(owner, target));
        pseudoToState.label = '';
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

      /// Create a transition from [from] state to a generated pseudo fork state.
      final smct = SMCTransition(
          from: findSMCState(owner, transition.fromStateDefinition.stateType),
          to: genJoinState(owner, transition.targetStates[0]));
      smct.label = transition.label;
      // smc.pseudoState = ']${transition.targetStates[0].toString()}.Join';
      // parent.parent.transitions.add(smc);
      expandPageBreaks(stateMachine, parent, smct);

      /// need to create a pseudostate to display the join bar.
      final pseudoToState = SMCTransition(
          from: genJoinState(owner, transition.targetStates[0]),
          to: findSMCState(owner, transition.targetStates[0]));
      pseudoToState.label = '';
      // parent.parent.transitions.add(pseudoToState);
      expandPageBreaks(stateMachine, parent, pseudoToState);
    }

    // on
    else //  (transition is OnTransition)
    {
      assert(transition is OnTransitionDefinition);
      for (final trigger in transition.triggerEvents) {
        final target = transition.targetStates[0];

        final smct = SMCTransition(
            from: owner,
            to: target == TerminalState
                ? genTerminalState(owner)
                : findSMCState(owner, target));
        smct.label = transition.labelForEvent(trigger);

        if (target == TerminalState) {
          /// The final transition is always placed outside the substate.
          expandPageBreaks(stateMachine, owner.parent, smct);
        } else {
          expandPageBreaks(stateMachine, owner, smct);
        }
      }
    }
    return transitions;
  }

  /// Generates a psuedo terminal state designed to be
  /// terminal state transition from  [fromState]
  static SMCTerminalState genTerminalState(SMCState fromState) {
    if (fromState.sd != null) {
      return SMCTerminalState(fromState, fromState.sd.stateType);
    } else {
      return SMCTerminalState(null, VirtualRoot);
    }
  }

  static SMCInitialState genInitialState(SMCState state) {
    if (state.sd != null) {
      return SMCInitialState(state.parent, state.sd.stateType);
    } else {
      /// must be pseudo state so use parent
      return SMCInitialState(state.parent, state.parent.sd.stateType);
    }
  }

  static SMCForkState genForkState(SMCState owner, Type stateType) {
    final fork = SMCForkState(owner, stateType);

    /// we assign an initial page no so we don't get npe's but it may need to be
    /// re-assigned.
    fork.pageNo = owner.pageNo;
    return fork;
  }

  static SMCJoinState genJoinState(SMCState owner, Type stateType) {
    final join = SMCJoinState(owner, stateType);

    /// we assign an initial page no so we don't get npe's but it may need to be
    /// re-assigned.
    join.pageNo = owner.pageNo;
    return join;
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

    final smcFrom = smcTransition.from;
    final smcTo = smcTransition.to;

    if (isOnSamePage(smcFrom, smcTo)) {
      owner.transitions.add(smcTransition);
      return;
    }

    final commonPage = smcFrom.findCommonPage(smcTo);

    if (smcFrom.isSiblingOf(smcTo)) {
      /// siblings will always be on the same page.
      owner.transitions.add(smcTransition);
    }

    /// from is an ancestor of to
    else if (smcFrom.isAncestorOf(smcTo)) {
      addEnterTransitions(owner, smcFrom, smcTo, smcTransition);
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

      // final commonPage = branches.from.findCommonPage(branches.to);
      // if (commonPage != null) {
      //   addDirectTransition(
      //       branches.from, branches.to, commonPage, smcTransition);
      // }

      /// the branches will be sibligs so we start
      /// by creating a bridging transition between the
      /// siblines.
      final bridgeTransition =
          SMCTransition(from: branches.from, to: branches.to);
      bridgeTransition.label = smcTransition.label;
      owner.transitions.add(bridgeTransition);

      addExitTransitions(owner, branches.from, smcFrom, smcTransition);
      addEnterTransitions(owner, branches.to, smcTo, smcTransition);
    }
  }

  // /// Adds a direct link between two states which MUST be on the same page.
  static void addDirectTransition(
      SMCState from, SMCState to, int commonPage, SMCTransition orginal) {
    assert(from.pageNo == to.pageNo);

    /// generate an exit from the current state
    final transition = SMCTransition(from: from, to: to);
    transition.label = orginal.label;

    // WHO is the owner here as I think it controls what page these go on which is possibly not the same as the commonPage.
    // Same goes for each of the other transitions.
    final owner = findPageOwner(from, commonPage);

    owner.transitions.add(transition);
  }

  static void addExitTransitions(SMCState owner, SMCState smcFrom,
      SMCState smcTo, SMCTransition original) {
    if (smcFrom == smcTo) return;

    if (isOnSamePage(smcFrom, smcTo)) {
      return;
    }

    /// generate an exit from the current state
    final transition =
        SMCTransition(from: smcFrom, to: genTerminalState(smcFrom));

    transition.label = original.label;

    owner.transitions.add(transition);

    /// final state transition on each page up to the target ancestor
    var parent = owner.parent;
    while (parent != smcTo) {
      /// generate an exit from the current state
      final transition =
          SMCTransition(from: parent, to: genTerminalState(parent));
      transition.label = original.label;
      if (parent.parent == null) break;
      assert(parent.parent != null);
      parent = parent.parent;

      parent.transitions.add(transition);
    }

    /// add final transtiion to the actual 'to' state
    final finalTransition = SMCTransition(from: parent, to: smcTo);
    finalTransition.label = original.label;
    smcTo.transitions.add(finalTransition);
  }

  /// Find the SMCState for the name.
  /// If the name is for a pseudo state then we return the state
  /// that the pseudo state name is based on.
  static SMCState findSMCState(SMCState owner, Type stateType) {
    /// traverse the tree back up to the virtual root and then search down from there
    /// until we find the matching sd.
    final root = getRoot(owner);

    // var matcher = name;
    // if (name.startsWith(']')) {
    //   /// psudo names are of the form ']state.type]
    //   /// and we just want the state name.
    //   matcher = name.split('.')[0].substring(1);
    // }

     final state =  findInTree<SMCState>(root, (node) => node.children,
        (child) => child.baseName == stateType.toString());

         if (state == null) {
      throw SMCatException(
          'FSM is in an inconsistent state. Unable to find state $stateType for ${owner.type}');
    }

    return state;
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

  /// Work our way up the tree from the given [state] until we find
  /// the exit straddle state on [targetPageNo].
  /// Each page can have an 'enter' straddle state and an 'exit' straddle state.
  /// The 'exit' straddle state is the straddle state that takes us to a child page.
  /// The 'enter' straddle state is the straddle state that takes to a parent page.
  static SMCState getStraddleStateForPage(SMCState state, int targetPageNo) {
    var current = state;
    while (current.pageNo != targetPageNo) {
      current = current.parent;
    }

    /// The first state we see on a new page should be a straddle state.
    /// assert(current.isStraddleState); of course if we are on the same page then no straddle state

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
    if (smcFrom == smcTo) return;

    /// On the 'to' page we show a 'initial' transition.
    ///
    var transition = SMCTransition(

        /// generate an init into [smcTo] from its parent
        from: genInitialState(smcTo),
        to: smcTo);
    transition.label = smcTransition.label;
    smcTo.parent.transitions.add(transition);

    /// Starting from the [smcTo] work our way back up to [smcFrom]
    /// Write an enter transition as we move to each new ancestor page
    var parent = smcTo.parent;
    var currentPageNo = smcTo.pageNo;
    while (currentPageNo > smcFrom.pageNo) {
      if (currentPageNo != parent.pageNo) {
        /// generate an init into the current state
        if (!parent.parent.isRoot) {
          // we are on a new page so show an init transition.
          final transition =
              SMCTransition(from: genInitialState(parent), to: parent);

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
    final to = getStraddleStateForPage(smcTo, smcFrom.pageNo);

    if (to != smcFrom) {
      transition = SMCTransition(
          // generate an exit from the current state
          from: smcFrom,
          to: to);
      transition.label = smcTransition.label;

      /// originally had parent.parent?
      parent.transitions.add(transition);
    }
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
