import 'dart:developer';
import 'dart:io';

import '../definitions/state_definition.dart';
import '../state_machine.dart';
import '../transitions/transition_definition.dart';
import '../virtual_root.dart';

/// Class exports a [StateMachine] to a dot notation file so that the
/// FMS can be visualised.
///
/// Exports the [StateMachine] to dot notation which can then
/// be used by xdot to display a diagram of the state machine.
/// 
/// ```bash
///
/// apt install xdot
///
/// https://www.graphviz.org/doc/info/lang.html
///
/// To visualise the resulting file graph run:
///
/// xdot <path>
/// ```
class DotExporter {
  DotExporter(this.stateMachine);
  final StateMachine stateMachine;
  final _edgePaths = <_EdgePath>[];
  var _terminalStateOrdinal = 1;

  /// creates a map of the terminal ordinals to what
  /// parent state they belong to.
  final _terminalsOwnedByRegion = <Type, List<int>>{};

  Future<void> export(String path) async {
    await stateMachine
        .traverseTree((stateDefinition, transitionDefinitions) async {
      for (final transitionDefinition in transitionDefinitions) {
        if (stateDefinition.isLeaf) {
          await _addEdgePath(stateDefinition, transitionDefinition);
        }
      }
    });

    _saveToDot(path);
  }

  Future<void> _addEdgePath(StateDefinition stateDefinition,
      TransitionDefinition transitionDefinition) async {
    var appended = false;

    String? region;

    final targetStates = transitionDefinition.targetStates;

    for (final targetState in targetStates) {
      final toDef = findStateDefinition(stateMachine, targetState);

      if (toDef != null && toDef.parent!.stateType != VirtualRoot) {
        region = toDef.parent!.stateType.toString();
      }

      for (final event in transitionDefinition.triggerEvents) {
        final node = _Edge(stateDefinition, event, toDef,
            region: region, terminal: toDef!.isTerminal);

        /// see if we have an existing path that ends with [fromState]
        for (final path in _edgePaths) {
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
    final file = File(path);
    final raf = file.openSync(mode: FileMode.write)
      ..writeStringSync('digraph fsm2 {\n');

    final edge = _edgePaths.first.first;
    raf
      ..writeStringSync('\tInitialState [shape=point];\n')
      ..writeStringSync(
          '\tInitialState -> ${edge.fromDefinition.stateType};\n');

    writeTransitions(raf);

    writeTerminals(raf, VirtualRoot, 0);

    _writeRegions(raf);
    raf
      ..writeStringSync('}')
      ..closeSync();
  }

  /// writes out a dot line for every transition.
  /// It also records any terminal states and creates a virtual transition
  /// to a terminal state.
  void writeTransitions(RandomAccessFile raf) {
    for (final edgePath in _edgePaths) {
      _Edge? edge = edgePath.first;

      while (edge != null) {
        raf.writeStringSync(
            '''\t${edge.fromDefinition.stateType} -> ${edge.toDefinition!.stateType} [label="${edge.event}"];\n''');

        // if the toState is a terminal state we need to write an extra
        // entry to show a transition to the virtual terminal state.
        if (edge.isDestinationTerminal) {
          addTerminalToSubGraph(edge.toDefinition!, _terminalStateOrdinal);

          /// we don't label terminal events and we make them a small dot.
          raf.writeStringSync(
              '''\t${edge.toDefinition!.stateType} -> TerminalState${_terminalStateOrdinal++};\n''');
        }

        edge = edge.next;
      }
    }
  }

  void _writeRegions(RandomAccessFile raf) {
    for (final stateDefinition in stateMachine.topStateDefinitions) {
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
      final regionName = region.stateType;

      raf.writeStringSync('''
      ${'\t' * level}// State: $regionName
${'\t' * level}subgraph cluster_$regionName {
\t${'\t' * level}graph [label="$regionName", bgcolor="/bugn9/$level", fontsize="20" ];
''');
      level++;

      /// put the parent state in the cluster box as well.
      // raf.writeStringSync(
      //     '${'\t' * level}${regionName} [style="filled" fillcolor="grey" color="black" fontsize="20"];\n');

      /// place each child state into the cluster box.
      // ignore: unnecessary_parenthesis
      raf.writeStringSync('${'\t' * (level)}// nested states\n');

      /// new line after 4 children.
      var breakCount = 4;
      raf.writeStringSync('\t' * level);
      for (final child in region.nestedStateDefinitions) {
        if (child.nestedStateDefinitions.isEmpty) {
          if (breakCount == 0) {
            raf.writeStringSync('\n${'\t' * level}');
            breakCount = 4;
          }
          raf.writeStringSync('${child.stateType}; ');
          breakCount--;
        }
      }
      raf.writeStringSync('\n');

      for (final child in region.nestedStateDefinitions) {
        if (child.nestedStateDefinitions.isNotEmpty) {
          _writeRegion(raf, child, level);
        }
      }

      writeTerminals(raf, regionName, level);

      raf.writeStringSync('''\n${'\t' * (level - 1)}}\n''');
    }
  }

  void writeTerminals(RandomAccessFile raf, Type regionName, int level) {
    final terminals = _terminalsOwnedByRegion[regionName];

    if (terminals != null) {
      /// write out a unique terminal state as a point for each state
      /// that had a terminal state.
      raf.writeStringSync('${'\t' * level}// terminal states\n');
      for (final terminal in terminals) {
        raf.writeStringSync(
            '${'\t' * level}TerminalState$terminal [shape=point];\n');
      }
    }
  }

  void addTerminalToSubGraph(
      StateDefinition terminalStateDefinition, int terminalStateOrdinal) {
    var terminalState = terminalStateDefinition.stateType;

    /// If a state has no children then it is a leaf.
    /// If it has a parent then the terminals should be displayed in the
    /// parents subgraph.
    if (terminalStateDefinition.nestedStateDefinitions.isEmpty &&
        terminalStateDefinition.parent.runtimeType != VirtualRoot) {
      terminalState = terminalStateDefinition.parent!.stateType;
    }

    final terminals = _terminalsOwnedByRegion[terminalState] ?? <int>[]
      ..add(terminalStateOrdinal);

    /// the state is owned by its parent.
    _terminalsOwnedByRegion[terminalStateDefinition.parent!.stateType] =
        terminals;
  }
}

/// Describes a linked list of edges
/// for the purposes of writing out each
/// transition to the dotx file.
class _EdgePath {
  _EdgePath(this.first) : last = first;
  _Edge first;
  _Edge last;

  void append(_Edge node) {
    last.next = node;
    last = node;
  }
}

/// Describes an event that transition from one state to another
class _Edge {
  _Edge(this.fromDefinition, this.event, this.toDefinition,
      {required this.terminal, this.region}) {
    log('''edge ${fromDefinition.stateType}:$event -> ${toDefinition!.stateType}''');
  }
  StateDefinition fromDefinition;
  Type event;
  StateDefinition? toDefinition;
  String? guard;
  String? region;

  /// If the toState is a terminal state (no events leave the state)
  bool terminal;

  _Edge? next;
  _Edge? prev;

  /// true if the toState is a terminal state.
  bool get isDestinationTerminal => terminal;
}
