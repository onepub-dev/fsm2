import 'dart:io';

import '../definitions/state_definition.dart';
import '../state_machine.dart';
import '../transitions/fork_transition.dart';
import '../transitions/join_transition.dart';
import '../types.dart';

/// Class exports a [StateMachine] to a Mermaid notation file so
///  that the FMS can be visualised.
///
/// https://github.com/mermaid-js/mermaid
///
/// Mermaid has cli tools which you can use during development:
///
/// https://github.com/mermaid-js/mermaid-cli
///
/// To visualise the resulting file graph run:
///
/// ``` bash
/// xdot <path>
/// ```
class MermaidExporter {
  // var terminalStateOrdinal = 1;

  /// creates a map of the terminal ordinals to what
  /// parent state they belong to.
  /// ```dart
  /// var terminalsOwnedByRegion = <Type, List<int>>{};
  /// ```
  MermaidExporter(this.stateMachine);
  final StateMachine stateMachine;

  void export(String path) {
    // await stateMachine.traverseTree((stateDefinition,
    //transitionDefinitions) async {
    //   for (var transitionDefinition in transitionDefinitions) {
    //     if (stateDefinition.isLeaf) {
    //       await _addEdgePath(stateDefinition, transitionDefinition);
    //     }
    //   }
    // });

    _save(path);
  }

  void _save(String path) {
    final file = File(path);
    final raf = file.openSync(mode: FileMode.write)

      /// version
      ..writeStringSync('stateDiagram-v2\n');

    const level = 0;

    for (final sd in stateMachine.topStateDefinitions) {
      if (sd.isAbstract) {
        writeRegion(raf, sd, level);
      } else {
        writeState(raf, sd, level);
      }
    }

    raf.closeSync();
  }

  String indent(int level) => '\t' * level;

  void writeRegion(RandomAccessFile raf, StateDefinition<State> sd, int level) {
    level++;

    /// Delcare the enter/exit points for the region
    raf
      ..writeStringSync('${indent(level)}[*] --> ${sd.stateType}\n')
      ..writeStringSync('${indent(level)}${sd.stateType} --> [*]\n')
      ..writeStringSync('${indent(level)}state ${sd.stateType} {\n');

    for (final child in sd.childStateDefinitions) {
      if (child.isAbstract) {
        writeRegion(raf, child, level);
      } else {
        writeState(raf, child, level);
      }
    }
    writeTransitions(raf, sd, level);
    raf.writeStringSync('${indent(level)}}\n');
  }

  void writeState(RandomAccessFile raf, StateDefinition<State> sd, int level) {
    level++;
    raf.writeStringSync('${indent(level)}${sd.stateType}\n');

    writeTransitions(raf, sd, level);
  }

  void writeTransitions(RandomAccessFile raf, StateDefinition sd, int level) {
    var pseudoStateId = 1;

    for (final transition in sd.getTransitions(includeInherited: false)) {
      if (transition is ForkTransitionDefinition) {
        writeFork(raf, sd, transition, level, pseudoStateId);
      } else if (transition is JoinTransitionDefinition) {
        writeJoin(raf, sd, transition, level, pseudoStateId);
      }

      pseudoStateId++;
    }
  }

  void writeFork(
      RandomAccessFile raf,
      StateDefinition sd,
      ForkTransitionDefinition<State, Event> transition,
      int level,
      int pseudoStateId) {
    /// forks are pseudo states which in mermaid need a name.
    /// as we model them as a transition we don't have a name.
    /// As such we use the states name followed by a
    ///  unqiue id to generate a name.
    final forkName = '${sd.stateType}$pseudoStateId';
    raf
      ..writeStringSync('${indent(level)}state $forkName <<fork>> \n')

      /// Add a transition into the fork
      ..writeStringSync(
          '''${indent(level)}${transition.fromStateDefinition.stateType} --> $forkName\n''')
      ..writeStringSync('${indent(level)}[*] --> $forkName\n');

    /// now add a transition from the fork to each target.
    for (final target in transition.targetStates) {
      raf.writeStringSync('${indent(level)}$forkName --> $target\n');
    }
  }

  void writeJoin(
      RandomAccessFile raf,
      StateDefinition sd,
      JoinTransitionDefinition<State, Event, State> transition,
      int level,
      int pseudoStateId) {
    /// joins are pseudo states which in mermaid need a name.
    /// as we model them as a transition we don't have a name.
    /// As such we use the states name followed by a
    /// unqiue id to generate a name.
    final joinName = '${sd.stateType}$pseudoStateId';
    raf.writeStringSync('${indent(level)}state $joinName <<join>> \n');

    /// Add a transition into the fork
    // raf.writeStringSync('${indent(level)}${transition.fromStateDefinition.stateType} --> ${joinName}\n');

    // /// now add a transition from each the fork to each target.
    // for (var event in transition.triggerEvents) {
    //   raf.writeStringSync('${indent(level)}${event} --> $joinName\n');
    // }

    for (final state in sd.childStateDefinitions) {
      raf.writeStringSync('${indent(level)}${state.stateType} --> $joinName\n');
    }

    raf.writeStringSync('${indent(level)}$joinName --> [*] \n');
  }
}
