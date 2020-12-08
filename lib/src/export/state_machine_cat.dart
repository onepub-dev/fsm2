import 'dart:io';
import 'package:fsm2/src/transitions/fork_transition.dart';
import 'package:fsm2/src/transitions/join_transition.dart';
import 'package:fsm2/src/transitions/on_transition.dart';
import 'package:fsm2/src/types.dart';

import 'package:fsm2/src/state_machine.dart';

import '../definitions/state_definition.dart';

/// Class exports a [StateMachine] to a Mermaid notation file so that the FMS can be visualised.
///
/// https://github.com/mermaid-js/mermaid
///
/// Mermaid has cli tools which you can use during development:
///
/// https://github.com/mermaid-js/mermaid-cli
///
/// To visualise the resulting file graph run:
///
/// ```
/// xdot <path>
/// ```
class StartMachineCatExporter {
  final StateMachine stateMachine;
  // var terminalStateOrdinal = 1;

  /// creates a map of the terminal ordinals to what
  /// parent state they belong to.
  /// var terminalsOwnedByRegion = <Type, List<int>>{};
  StartMachineCatExporter(this.stateMachine);

  void export(String path)  {
    // await stateMachine.traverseTree((stateDefinition, transitionDefinitions) async {
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
    final raf = file.openSync(mode: FileMode.write);

    /// version
    raf.writeStringSync('initial,\n');

    const level = 0;

    var firstpass = true;
    for (final sd in stateMachine.topStateDefinitions) {
      if (!firstpass) {
        raf.writeStringSync(',\n');
      }
      firstpass = false;
      if (sd.isAbstract) {
        writeRegion(raf, sd, level);
      } else {
        writeState(raf, sd, level);
      }
    }
    raf.writeStringSync(';\n');

    raf.closeSync();
  }

  String indent(int level) {
    return '\t' * (level - 1);
  }

  void writeRegion(RandomAccessFile raf, StateDefinition<State> sd, int level) {
    // ignore: parameter_assignments
    level++;

    /// start the region
    raf.writeStringSync('${indent(level)}${sd.stateType}\n');
    raf.writeStringSync('${indent(level)}{\n');

    // /// Delcare the enter/exit points for the region
    // raf.writeStringSync('${indent(level)}[*] => ${sd.stateType}\n');

    // raf.writeStringSync('${indent(level)}${sd.stateType} => [*]\n');
    // raf.writeStringSync('${indent(level)}state ${sd.stateType} {\n');

    var firstpass = true;
    var sawState = false;

    for (final child in sd.childStateDefinitions) {
      if (!firstpass) {
        raf.writeStringSync(',\n');
      }
      firstpass = false;

      if (child.isAbstract) {
        sawState = true;
        writeRegion(raf, child, level);
      } else {
        sawState = true;
        writeState(raf, child, level);
      }
    }
    if (sawState) {
      raf.writeStringSync(';\n');
    }
    raf.writeStringSync('${indent(level)}}');
    writeTransitions(raf, sd, level);
    //  raf.writeStringSync('\n${indent(level)}}\n');
  }

  void writeState(RandomAccessFile raf, StateDefinition<State> sd, int level) {
    // ignore: parameter_assignments
    level++;
    raf.writeStringSync('${indent(level)}${sd.stateType}');

    writeTransitions(raf, sd, level);
  }

  void writeTransitions(RandomAccessFile raf, StateDefinition sd, int level) {
    var firstpass = true;

    for (final transition in sd.getTransitions(includeInherited: false)) {
      if (firstpass) {
        raf.writeStringSync('${indent(level)}\n');
        firstpass = false;
      }
      if (transition is OnTransitionDefinition) {
        raf.writeStringSync(
            '${indent(level)}${transition.fromStateDefinition.stateType} => ${transition.toState} : ${transition.triggerEvents.first},\n');
      }

      //  else if (transition is ForkTransitionDefinition) {
      //   writeFork(raf, sd, transition, level, pseudoStateId);
      // } else if (transition is JoinTransitionDefinition) {
      //   writeJoin(raf, sd, transition, level, pseudoStateId);
      // }

    }
    if (firstpass == false) raf.writeStringSync('${indent(level)}\n');
  }

  void writeFork(
      RandomAccessFile raf,
      StateDefinition sd,
      ForkTransitionDefinition<State, Event> transition,
      int level,
      int pseudoStateId) {
    /// forks are pseudo states which in mermaid need a name.
    /// as we model them as a transition we don't have a name.
    /// As such we use the states name followed by a unqiue id to generate a name.
    final forkName = ']${sd.stateType}$pseudoStateId';
    raf.writeStringSync('${indent(level)}$forkName; \n');

    /// Add a transition into the fork
    raf.writeStringSync(
        '${indent(level)}${transition.fromStateDefinition.stateType} => $forkName;\n');
    // raf.writeStringSync('${indent(level)}[*] => $forkName;\n');

    // /// now add a transition from the fork to each target.
    // for (var target in transition.targetStates) {
    //   raf.writeStringSync('${indent(level)}$forkName => ${target};\n');
    // }
  }

  void writeJoin(
      RandomAccessFile raf,
      StateDefinition sd,
      JoinTransitionDefinition<State, Event, State> transition,
      int level,
      int pseudoStateId) {
    /// joins are pseudo states which in mermaid need a name.
    /// as we model them as a transition we don't have a name.
    /// As such we use the states name followed by a unqiue id to generate a name.
    final joinName = ']${sd.stateType}$pseudoStateId';
    raf.writeStringSync('${indent(level)}$joinName \n');

    // for (var state in sd.childStateDefinitions.values) {
    //   raf.writeStringSync('${indent(level)}${state.stateType} => $joinName;\n');
    // }

    // raf.writeStringSync('${indent(level)}$joinName => [*] \n');
  }
}
