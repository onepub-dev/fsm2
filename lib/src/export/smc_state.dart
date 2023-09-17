import '../definitions/state_definition.dart';
import '../state_machine.dart';
import '../types.dart';
import 'branches.dart';
import 'exporter.dart';
import 'smc_transition.dart';

enum Color { none, blue, orange }

extension ColorExt on Color {
  String get name => toString().split('.')[1].replaceAll('_', ' ');
}

enum SMCStateType {
  root,
  initial,
  coregion,
  region,
  fork,
  join,
  simple,
  terminal
}

class SMCState {
  SMCState.root({required this.name, required this.pageBreak, String? label})
      : type = SMCStateType.root,
        parent = null,
        _label = label ?? name;

  SMCState.pseudo(
      {required this.parent,
      required this.name,
      required this.type,
      required this.pageBreak,
      String? label})
      : _label = label ?? name;

  ///
  /// Build the SMSState tree
  ///
  SMCState.child(
      {required this.sd, required this.pageNo, this.parent, bool? pageBreak}) {
    this.pageBreak = pageBreak ?? sd.pageBreak;

    var childPageNo = pageNo;
    if (this.pageBreak) {
      childPageNo++;
    }

    if (sd.isLeaf) {
      name = sd.stateType.toString();
      label = name;
      type = SMCStateType.simple;
      return;
    } else {
      if (sd.isCoRegion) {
        name = '${sd.stateType}.parallel';
        label = sd.stateType.toString();
        type = SMCStateType.coregion;
      } else {
        name = sd.stateType.toString();
        label = name;
        type = SMCStateType.region;
        initialChildState = sd.initialState.toString();
      }
      for (final child in sd.childStateDefinitions) {
        children
            .add(SMCState.child(parent: this, sd: child, pageNo: childPageNo));
      }
    }
  }
  late final SMCState? parent;
  late final StateDefinition<State> sd;
  late final String name;
  late final String? _label;
  late final SMCStateType type;

  /// If true then this state and all child states will
  /// be written to new page file.
  /// We say that the state where the page break occurs 'straddles'
  /// two pages. We call this a 'straddle' state.

  late final bool pageBreak;

  /// the page no. this SMCState appears.
  /// A state with a page break will actually appear on two pages.
  ///
  /// It will appear on the page of its parent and it will
  /// also be the 'top level' state on the new page.
  /// This [pageNo] refers to the page that its parent is on.
  int pageNo = 0;

  /// for a region one of its child are the initial state.
  String? initialChildState;
  List<SMCTransition> transitions = <SMCTransition>[];
  List<SMCState> children = <SMCState>[];

  /// We say that the state where the page break occurs 'straddles'
  /// two pages. We call this a 'straddle' state.
  bool get isStraddleState => pageBreak;

  String get label => _label ?? name;

  set label(String label) => _label = label;

  /// If this state straddles two pages
  /// then this is the pageNo of the child page
  /// where we display the state as a top level nested state.
  int get straddleChildPage {
    assert(isStraddleState, 'state cannot straddle two pages');

    return pageNo + 1;
  }

  /// If this state straddles two pages
  /// then this is the pageNo of the parent page
  /// where we display the state as a simple state.
  int? get straddleParentPage {
    assert(isStraddleState, 'state cannot straddle two pages');

    return pageNo;
  }

  bool get isRoot => type == SMCStateType.root;

  /// If the state is a co-region then this method returns
  /// the original state name.
  ///
  /// e.g. Dead.parallel returns Dead.
  String? get baseName {
    var baseName = name;
    // if (name.startsWith(']')) {
    if (sd.isCoRegion) {
      /// psudo names are of the form ']state.type]
      /// and we just want the state name.
      baseName = name.split('.')[0];
    }
    return baseName;
  }

  void buildTransitions(StateMachine stateMachine) {
    for (final transition in sd.getTransitions(includeInherited: false)) {
      transitions.addAll(SMCTransition.build(stateMachine, this, transition));
    }
  }

  void addChild(SMCState child) {
    children.add(child);
  }

  ///
  /// write the state to the file.
  ///
  void write(Exporter exporter, {required int indent}) {
    var transitionPage = pageNo;
    var bodyPage = pageNo;
    if (isStraddleState) {
      bodyPage = straddleChildPage;
      transitionPage = straddleChildPage;
    }

    /// we don't write out the name of the VirtualRoot
    if (type != SMCStateType.root) {
      _writeName(exporter, pageNo, indent,
          color: isStraddleState ? Color.blue : Color.none);

      /// straddle states appear on two pages.
      if (isStraddleState) {
        _writeName(exporter, bodyPage, indent, color: Color.none);
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
      if (child != children.last) {
        exporter.append(',', page: bodyPage);
      }
    }

    if (children.isNotEmpty) {
      exporter.append(';', page: bodyPage);
    }

    /// Write out the initial state if this isn't a leaf
    if (initialChildState != null) {
      exporter.write('$initialChildState.initial => $initialChildState;',
          page: bodyPage, indent: indent + 1);
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

  bool hasBody() =>
      (children.isNotEmpty || transitions.isNotEmpty) &&
      type != SMCStateType.root;

  void _writeName(Exporter exporter, int pageNo, int indent,
      {required Color color}) {
    final line = StringBuffer();
    var closeBracket = false;
    if (name == label) {
      line.write(name);
      if (color != Color.none) {
        closeBracket = true;
        line.write(' [color="${color.name}"');
      }
    } else {
      closeBracket = true;
      line.write('$name [label="$label"');
      if (color != Color.none) {
        line.write(' color="${color.name}"');
      }
    }
    if (closeBracket) {
      line.write(']');
    }

    exporter.write(line.toString(), indent: indent, page: pageNo);
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(covariant SMCState other) => hashCode == other.hashCode;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => name.hashCode + label.hashCode + type.hashCode;

  @override
  String toString() => name;

  /// Check if this state is a decendant of [other]
  bool isDescendantOf(SMCState other) {
    var current = this;

    while (!current.isRoot && current != other) {
      current = current.parent!;
    }

    /// if we didn't get to the root then we found the other
    /// so we must be a descendant.
    return !current.isRoot;
  }

  /// Find the common ancestor of the two given states
  /// and returns the two branches from that ancestor
  /// that lead to those states.
  Branches findBranchPoint(SMCState to) {
    final otherPath = _SMCStatePath.fromState(to);

    final ourPath = _SMCStatePath.fromState(this);

    final ancestor = _findCommonAncestor(ourPath, otherPath);

    late final SMCState _to;
    late final SMCState _from;

    for (final state in ourPath.path) {
      if (state.parent == ancestor) {
        _from = state;
        break;
      }
    }

    for (final state in otherPath.path) {
      if (state.parent == ancestor) {
        _to = state;
        break;
      }
    }
    return Branches(from: _from, to: _to);
  }

  SMCState? _findCommonAncestor(
      _SMCStatePath ourPath, _SMCStatePath otherPath) {
    for (final state in ourPath.path) {
      if (otherPath.isInPath(state)) {
        return state;
      }
    }

    /// we should never get here as the root is a common ancestor.
    assert(false, 'should never happen');
    return null;
  }

  /// Check whether this and other reside on a common page.
  /// We are checking both straddle pages if necessary.
  int? findCommonPage(SMCState other) {
    final pages = <int?>{}..add(pageNo);
    if (pages.contains(other.pageNo)) {
      return pageNo;
    }

    pages.add(other.pageNo);

    if (isStraddleState) {
      if (pages.contains(straddleChildPage)) {
        return straddleChildPage;
      }
      pages.add(straddleChildPage);
    }

    if (other.isStraddleState) {
      if (pages.contains(other.straddleChildPage)) {
        return other.straddleChildPage;
      }
    }

    /// no common page.
    return null;
  }

  bool isSiblingOf(SMCState other) => other.parent == parent;

  bool isAncestorOf(SMCState other) {
    SMCState? parent = other;
    while (parent != this && !parent!.isRoot) {
      parent = parent.parent;
    }
    return parent == this;
  }
}

/// describes the set of ancestors to a state.
class _SMCStatePath {
  _SMCStatePath.fromState(SMCState state) {
    var parent = state;
    while (!parent.isRoot) {
      path.add(parent);
      parent = parent.parent!;
    }

    // add the virtual root.
    path.add(parent);
  }

  /// list of states
  List<SMCState> path = <SMCState>[];

  /// true if the passed state is in the path.
  bool isInPath(SMCState state) => path.contains(state);
}
