import 'package:fsm2/src/export/smc_transition.dart';
import '../definitions/state_definition.dart';
import 'package:fsm2/src/types.dart';
import 'package:meta/meta.dart';

import 'exporter.dart';

enum SMCStateType { root, coregion, region, fork, join, simple }

class SMCState {
  SMCState parent;
  String name;
  String label;
  SMCStateType type;

  /// If true then this state and all child states will
  /// be written to new page file.
  bool pageBreak = false;

  /// for a region one of its child are the initial state.
  String initialChildState;
  List<SMCTransition> transitions = <SMCTransition>[];
  List<SMCState> children = <SMCState>[];

  SMCState({@required this.name, @required this.type, @required this.pageBreak});

  ///
  /// Build the SMSState tree
  ///
  SMCState.build(this.parent, StateDefinition<State> sd) {
    pageBreak = sd.pageBreak;
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
  void write(Exporter exporter, {@required int indent, @required int page}) {
    /// we don't write out the name of the VirtualRoot
    if (type != SMCStateType.root) {
      /// version
      if (name == label || label == null) {
        exporter.write(name, indent: indent, page: page);
      } else {
        exporter.write('$name [label="$label"]', indent: indent, page: page);
      }
    }

    if (hasBody()) {
      exporter.append(' {', page: page);
      //exporter.endLine(page: page);
    }

    /// write out child states.
    for (var child in children) {
      child.write(exporter, indent: indent + 1, page: page);
      if (child != children.last) exporter.append(',', page: page);
    }

    if (children.isNotEmpty) exporter.append(';', page: page);

    /// Write out the initial state if this isn't a leaf
    if (initialChildState != null) {
      exporter.write('${initialChildState}.initial => $initialChildState;', page: page, indent: indent + 1);
    }

    /// write out child transitions
    for (var transition in transitions) {
      transition.write(exporter, indent: indent + 1, page: page);
    }

    if (hasBody()) {
      exporter.write('}', indent: indent, page: page);
    }
  }

  bool hasBody() => (children.isNotEmpty || transitions.isNotEmpty) && type != SMCStateType.root;
}
