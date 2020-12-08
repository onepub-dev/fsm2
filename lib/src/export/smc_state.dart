import 'package:fsm2/src/types.dart';
import 'package:meta/meta.dart';

import '../definitions/state_definition.dart';
import '../state_machine.dart';
import 'exporter.dart';
import 'smc_transition.dart';

enum SMCStateType { root, coregion, region, fork, join, simple }

class SMCState {
  SMCState parent;
  StateDefinition<State> sd;
  String name;
  String label;
  SMCStateType type;

  /// If true then this state and all child states will
  /// be written to new page file.
  /// We say that the state where the page break occurs 'straddles'
  /// two pages. We call this a 'straddle' state.

  bool pageBreak = false;

  /// the page no. this SMCState appears.
  /// A state with a page break will actually appear on two pages.
  ///
  /// It will appear on the page of its parent and it will
  /// also be the 'top level' state on the new page.
  /// This [pageNo] refers to the page that its parent is on.
  int pageNo;

  /// for a region one of its child are the initial state.
  String initialChildState;
  List<SMCTransition> transitions = <SMCTransition>[];
  List<SMCState> children = <SMCState>[];

  SMCState({@required this.name, @required this.type, @required this.pageBreak});

  /// We say that the state where the page break occurs 'straddles'
  /// two pages. We call this a 'straddle' state.
  bool get isStraddleState => pageBreak;

  /// If this state straddles two pages
  /// then this is the pageNo of the child page
  /// where we display the state as a top level nested state.
  int get straddleChildPage {
    assert(isStraddleState);

    return pageNo + 1;
  }

  /// If this state straddles two pages
  /// then this is the pageNo of the parent page
  /// where we display the state as a simple state.
  int get straddleParentPage {
    assert(isStraddleState);

    return pageNo;
  }

  ///
  /// Build the SMSState tree
  ///
  SMCState.build(StateMachine stateMachine, this.parent, this.sd, {@required int page}) {
    pageBreak = sd.pageBreak;
    pageNo = page;
    assert(pageNo != null);

    var childPageNo = pageNo;
    if (pageBreak) childPageNo++;

    if (sd.isLeaf) {
      name = sd.stateType.toString();
      label = name;
      type = SMCStateType.simple;
    } else {
      if (sd.isCoRegion) {
        name = '${sd.stateType.toString()}.parallel';
        label = 'sd.stateType.toString()';
        type = SMCStateType.coregion;
      } else {
        name = 'sd.stateType.toString()';
        label = name;
        type = SMCStateType.region;
        initialChildState = sd.initialState.toString();
      }
      for (final child in sd.childStateDefinitions) {
        children.add(SMCState.build(stateMachine, this, child, page: childPageNo));
      }
    }
  }

  void buildTransitions(StateMachine stateMachine) {
    for (final transition in sd.getTransitions(includeInherited: false)) {
      transitions.addAll(SMCTransition.build(stateMachine, this, transition));
    }

    // remove duplicate psuedo states
    transitions = transitions.toSet().toList();
  }

  void addChild(SMCState child) {
    children.add(child);
  }

  ///
  /// write the state to the file.
  ///
  void write(Exporter exporter, {@required int indent}) {
    var transitionPage = pageNo;
    var bodyPage = pageNo;
    if (isStraddleState) {
      bodyPage = straddleChildPage;
      transitionPage = straddleChildPage;
    }

    /// we don't write out the name of the VirtualRoot
    if (type != SMCStateType.root) {
      /// version
      if (name == label || label == null) {
        exporter.write(name, indent: indent, page: bodyPage);
      } else {
        exporter.write('$name [label="$label"]', indent: indent, page: bodyPage);
      }
    }

    if (hasBody()) {
      exporter.append(' {', page: bodyPage);
    }

    /// children will be on a new page so reset indent.
    if (pageBreak) {
      // ignore: parameter_assignments
      indent = 0;
    }

    /// write out child states.
    for (final child in children) {
      child.write(exporter, indent: indent + 1);
      if (child != children.last) exporter.append(',', page: bodyPage);
    }

    if (children.isNotEmpty) exporter.append(';', page: bodyPage);

    /// Write out the initial state if this isn't a leaf
    if (initialChildState != null) {
      exporter.write('$initialChildState.initial => $initialChildState;', page: bodyPage, indent: indent + 1);
    }

    /// write out child transitions
    for (final transition in transitions) {
      transition.write(exporter, indent: indent + 1, page: transitionPage);
    }

    if (hasBody()) {
      exporter.write('}', indent: indent, page: bodyPage);
      if (isStraddleState) {
        exporter.append(';', page: bodyPage);
      }
    }
  }

  bool hasBody() => (children.isNotEmpty || transitions.isNotEmpty) && type != SMCStateType.root;
}
