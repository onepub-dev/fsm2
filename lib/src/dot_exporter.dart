import 'dart:io';
import 'package:meta/meta.dart';

import 'package:fsm2/src/state_machine.dart';

import 'state_definition.dart';
import 'transitions/transition_definition.dart';

/// Class exports a [StateMachine] to a dot notation file so that the FMS can be visualised.
///
/// Exports the [StateMachine] to dot notation which can then
/// be used by xdot to display a diagram of the state machine.
///
/// apt install xdot
///
/// https://www.graphviz.org/doc/info/lang.html
///
/// To visualise the resulting file graph run:
///
/// ```
/// xdot <path>
/// ```
class DotExporter {
  final StateMachine stateMachine;
  final _edgePaths = <_EdgePath>[];
  var terminalStateOrdinal = 1;

  /// creates a map of the terminal ordinals to what
  /// parent state they belong to.
  var terminalsOwnedByRegion = <Type, List<int>>{};
  DotExporter(this.stateMachine);

  void export(String path) async {
    await stateMachine.traverseTree((stateDefinition, transitionDefinitions) async {
      for (var transitionDefinition in transitionDefinitions) {
        if (stateDefinition.isLeaf) {
          await _addEdgePath(stateDefinition, transitionDefinition);
        }
      }
    });

    await _saveToDot(path);
  }

  Future<void> _addEdgePath(StateDefinition stateDefinition, TransitionDefinition transitionDefinition) async {
    var appended = false;

    String cluster;

    var targetStates = await transitionDefinition.targetStates;

    for (var targetState in targetStates) {
      var toDef = stateMachine.findStateDefinition(targetState);

      if (toDef != null && toDef.parent != VirtualRoot().definition) {
        cluster = toDef.parent.stateType.toString();
      }

      for (var event in transitionDefinition.triggerEvents) {
        var node = _Edge(stateDefinition, event, toDef, region: cluster, terminal: toDef.isTerminal);

        /// see if we have an existing path that ends with [fromState]
        for (var path in _edgePaths) {
          if (path.last.fromDefinition.stateType == stateDefinition.stateType) {
            path.append(node);
            appended = true;
            break;
          }
        }

        if (!appended) {
          _edgePaths.add(_EdgePath(node));
        }
      }
    }
  }

  void _saveToDot(String path) {
    var file = File(path);
    var raf = file.openSync(mode: FileMode.write);

    raf.writeStringSync('digraph fsm2 {\n');

    var edge = _edgePaths.first.first;
    raf.writeStringSync('\tInitialState [shape=point];\n');
    raf.writeStringSync('\tInitialState -> ${edge.fromDefinition.stateType};\n');

    writeTransitions(raf);

    writeTerminals(raf, VirtualRoot, 0);

    _writeRegions(raf);
    raf.writeStringSync('}');

    raf.closeSync();
  }

  /// writes out a dot line for every transition.
  /// It also records any terminal states and creates a virtual transition
  /// to a terminal state.
  void writeTransitions(RandomAccessFile raf) {
    for (var edgePath in _edgePaths) {
      var edge = edgePath.first;

      while (edge != null) {
        raf.writeStringSync(
            '\t${edge.fromDefinition.stateType} -> ${edge.toDefinition.stateType} [label="${edge.event}"];\n');

        // if the toState is a terminal state we need to write an extra
        // entry to show a transition to the virtual terminal state.
        if (edge.isDestinationTerminal) {
          addTerminalToSubGraph(edge.toDefinition, terminalStateOrdinal);

          /// we don't label terminal events and we make them a small dot.
          raf.writeStringSync('\t${edge.toDefinition.stateType} -> TerminalState${terminalStateOrdinal++};\n');
        }

        edge = edge.next;
      }
    }
  }

  void _writeRegions(RandomAccessFile raf) {
    for (var stateDefinition in stateMachine.topStateDefinitions) {
      _writeRegion(raf, stateDefinition, 1);
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

  /// Each regions (nested or concurrent) we write as a graphwiz 'subgraph'
  void _writeRegion(RandomAccessFile raf, StateDefinition region, int level) {
    if (region.nestedStateDefinitions.isNotEmpty) {
      var regionName = region.stateType;

      raf.writeStringSync('''\n${'\t' * level}// State: $regionName
${'\t' * level}subgraph cluster_${regionName} {
\t${'\t' * level}graph [label="${regionName}", bgcolor="/bugn9/$level", fontsize="20" ];
''');
      level++;

      /// put the parent state in the cluster box as well.
      // raf.writeStringSync(
      //     '${'\t' * level}${regionName} [style="filled" fillcolor="grey" color="black" fontsize="20"];\n');

      /// place each child state into the cluster box.
      raf.writeStringSync('${'\t' * (level)}// nested states\n');

      /// new line after 4 children.
      var breakCount = 4;
      raf.writeStringSync('${'\t' * (level)}');
      for (var child in region.nestedStateDefinitions) {
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

      for (var child in region.nestedStateDefinitions) {
        if (child.nestedStateDefinitions.isNotEmpty) {
          _writeRegion(raf, child, level);
        }
      }

      writeTerminals(raf, regionName, level);

      raf.writeStringSync('''\n${'\t' * (level - 1)}}\n''');
    }
  }

  void writeTerminals(RandomAccessFile raf, Type regionName, int level) {
    var terminals = terminalsOwnedByRegion[regionName];

    if (terminals != null) {
      /// write out a unique terminal state as a point for each state that had a terminal state.
      raf.writeStringSync('${'\t' * level}// terminal states\n');
      for (var terminal in terminals) {
        raf.writeStringSync('${'\t' * level}TerminalState$terminal [shape=point];\n');
      }
    }
  }

  void addTerminalToSubGraph(StateDefinition terminalStateDefinition, int terminalStateOrdinal) {
    var terminalState = terminalStateDefinition.stateType;

    /// If a state has no children then it is a leaf.
    /// If it has a parent then the terminals should be displayed in the
    /// parents subgraph.
    if (terminalStateDefinition.nestedStateDefinitions.isEmpty &&
        terminalStateDefinition.parent != VirtualRoot().definition) {
      terminalState = terminalStateDefinition.parent.stateType;
    }

    var terminals = terminalsOwnedByRegion[terminalState] ?? <int>[];
    terminals.add(terminalStateOrdinal);

    /// the state is owned by its parent.
    terminalsOwnedByRegion[terminalStateDefinition.parent.stateType] = terminals;
  }
}

/// Describes a linked list of edges
/// for the purposes of writing out each
/// transition to the dotx file.
class _EdgePath {
  _Edge first;
  _Edge last;

  _EdgePath(this.first) : last = first;

  void append(_Edge node) {
    last.next = node;
    last = node;
  }
}

/// Describes an event that transition from one state to another
class _Edge {
  StateDefinition fromDefinition;
  Type event;
  StateDefinition toDefinition;
  String guard;
  String region;

  /// If the toState is a terminal state (no events leave the state)
  bool terminal;

  _Edge next;
  _Edge prev;

  _Edge(this.fromDefinition, this.event, this.toDefinition, {@required this.terminal, this.region}) {
    print('edge ${fromDefinition.stateType}:$event -> ${toDefinition.stateType}');
  }

  /// true if the toState is a terminal state.
  bool get isDestinationTerminal => terminal;
}
