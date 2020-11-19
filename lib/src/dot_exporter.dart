import 'dart:io';

import 'package:fsm2/src/state_machine.dart';
import 'package:fsm2/src/transition_definition.dart';

import 'state_definition.dart';
import 'types.dart';

/// Class exports a [StateMachine] to a dot notation file so that the FMS can be visualised.
///
/// Exports the [StateMachine] to dot notation which can then
/// be used by xdot to display a diagram of the state machine.
///
/// apt install xdot
///
/// https://www.graphviz.org/doc/info/lang.html
///
/// The export can only deal with static transisions ([on] not [onDynamic])
/// as it has no way of determining the final state for dynamic transitions.
///
/// To visualise the resulting file graph run:
///
/// ```
/// xdot <path>
/// ```
class DotExporter {
  final StateMachine stateMachine;
  var terminalStateOrdinal = 1;

  /// creates a map of the terminal ordinals to what
  /// parent state they belong to.
  var terminalToCluster = <Type, List<int>>{};
  DotExporter(this.stateMachine);

  Future<void> _addNode(
      List<_NodePath> nodeRoots, StateDefinition stateDefinition, TransitionDefinition transitionDefinition) async {
    var appended = false;

    String cluster;

    var toState = await transitionDefinition.toState;

    var toDef = stateMachine.findStateDefinition(toState);

    if (toDef != null && toDef.parent != null) {
      cluster = toDef.parent.stateType.toString();
    }

    var node = _Node(stateDefinition, transitionDefinition.eventType, toState, cluster: cluster);

    /// see if we have a path that ends with [fromState]
    for (var path in nodeRoots) {
      if (path.last.fromDefinition.stateType == stateDefinition.stateType) {
        path.append(node);
        appended = true;
        break;
      }
    }

    if (!appended) {
      nodeRoots.add(_NodePath(node));
    }
  }

  void _saveToDot(String path, List<_NodePath> stateRoots) {
    var file = File(path);
    var raf = file.openSync(mode: FileMode.write);

    raf.writeStringSync('digraph fsm2 {\n');

    writeTransitions(raf, stateRoots);

    _writeSubGraphs(raf);
    raf.writeStringSync('}');

    raf.closeSync();
  }

  void writeTransitions(RandomAccessFile raf, List<_NodePath> stateRoots) {
    for (var root in stateRoots) {
      var node = root.first;
      while (node != null) {
        // print('${node.toState}');
        if (node.event == TerminalEvent) {
          addTerminalToSubGraph(node.fromDefinition, terminalStateOrdinal);

          /// we don't label terminal events and we make them a small dot.
          raf.writeStringSync(
              '\t${node.fromDefinition.stateType} -> ${node.toState}${terminalStateOrdinal++} [shape = point];\n');
        } else {
          raf.writeStringSync('\t${node.fromDefinition.stateType} -> ${node.toState} [label="${node.event}"];\n');
        }
        node = node.next;
      }
    }
  }

  void _writeSubGraphs(RandomAccessFile raf) {
    for (var stateDefinition in stateMachine.topStateDefinitions) {
      _writeSubGraph(raf, stateDefinition, 1);
    }
  }

// digraph fsm2 {
//         Alive -> Young [label="OnBirthday"];
//         Alive -> MiddleAged [label="OnBirthday"];
//         Alive -> Old [label="OnBirthday"];
//         Alive -> Dead [label="OnDeath", lhead="clusterDead", compound=true];
//         Dead -> InHeaven [label="OnGood"];
//         Dead -> InHeaven [label="OnGood"];
//         Dead -> InHell [label="OnBad"];
//       subgraph clusterDead {
//                 graph [label="Dead", compound=true];
//           Dead, InHeaven; InHell;
//         }
// }
// ~

  void _writeSubGraph(RandomAccessFile raf, StateDefinition stateDefinition, int level) {
    if (stateDefinition.nestedStateDefinitions.isNotEmpty) {
      var name = stateDefinition.stateType;

      raf.writeStringSync('''\n${'\t' * level}// State: $name
${'\t' * level}subgraph cluster_${name} {
\t${'\t' * level}graph [label="${name}", bgcolor="/bugn9/$level", fontsize="20" ];
''');
      level++;

      /// put the parent state in the cluster box as well.
      raf.writeStringSync('${'\t' * level}${name} [style="filled" fillcolor="grey" color="black" fontsize="20"];\n');

      /// place each child state into the cluster box.
      raf.writeStringSync('${'\t' * (level)}// nested states\n');

      /// new line after 4 children.
      var breakCount = 4;
      raf.writeStringSync('${'\t' * (level)}');
      for (var child in stateDefinition.nestedStateDefinitions) {
        if (child.nestedStateDefinitions.isEmpty) {
          if (breakCount == 0) {
            raf.writeStringSync('\n${'\t' * (level)}');
            breakCount = 4;
          }
          raf.writeStringSync('${child.stateType}; ');
          breakCount--;
        }
      }
      raf.writeStringSync('\n');

      for (var child in stateDefinition.nestedStateDefinitions) {
        if (child.nestedStateDefinitions.isNotEmpty) {
          _writeSubGraph(raf, child, level);
        }
      }

      writeTerminals(raf, name, level);

      raf.writeStringSync('''\n${'\t' * (level - 1)}}\n''');
    }
  }

  void export(String path) async {
    var nodeRoots = <_NodePath>[];
    await stateMachine.traverseTree((stateDefinition, transitionDefinition) async =>
        await _addNode(nodeRoots, stateDefinition, transitionDefinition));

    await _saveToDot(path, nodeRoots);
  }

  void writeTerminals(RandomAccessFile raf, Type name, int level) {
    var terminals = terminalToCluster[name];

    if (terminals != null) {
      /// write out a unique terminal state as a point for each state that had a terminal state.
      raf.writeStringSync('${'\t' * level}// terminal states\n');
      for (var terminal in terminals) {
        raf.writeStringSync('${'\t' * level}TerminalState$terminal [shape=point];\n');
      }
    }
  }

  void addTerminalToSubGraph(StateDefinition fromDefinition, int terminalStateOrdinal) {
    var fromState = fromDefinition.stateType;

    /// If a state has no children then it is a leaf.
    /// If it has a parent then the terminals should be displayed in the
    /// parents subgraph.
    if (fromDefinition.nestedStateDefinitions.isEmpty && fromDefinition.parent != null) {
      fromState = fromDefinition.parent.stateType;
    }

    var terminals = terminalToCluster[fromState] ?? <int>[];
    terminals.add(terminalStateOrdinal);
    terminalToCluster[fromState] = terminals;
  }
}

class _NodePath {
  _Node first;
  _Node last;

  _NodePath(this.first) : last = first;

  void append(_Node node) {
    last.next = node;
    last = node;
  }
}

class _Node {
  StateDefinition fromDefinition;
  Type event;
  Type toState;
  String guard;
  String cluster;

  _Node next;
  _Node prev;

  _Node(this.fromDefinition, this.event, this.toState, {this.cluster}) {
    print('node ${fromDefinition.stateType} $event $toState');
  }
}
