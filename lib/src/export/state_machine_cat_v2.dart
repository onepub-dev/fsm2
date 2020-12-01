import 'dart:io';

import 'package:fsm2/src/state_machine.dart';

import 'smc_state.dart';

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
class StartMachineCatV2Exporter {
  final StateMachine stateMachine;
  final SMCState virtualRoot = SMCState(name: 'initial', type: SMCStateType.root);

  /// creates a map of the terminal ordinals to what
  /// parent state they belong to.
  /// var terminalsOwnedByRegion = <Type, List<int>>{};
  StartMachineCatV2Exporter(this.stateMachine);

  void export(String path) async {
    var smcState = build();
    await _save(path, smcState);
  }

  SMCState build() {
    for (var child in stateMachine.topStateDefinitions) {
      virtualRoot.addChild(SMCState.build(virtualRoot, child));
    }

    return virtualRoot;
  }

  void _save(String path, SMCState smcState) {
    var file = File(path);
    var raf = file.openSync(mode: FileMode.write);

    var indent = 0;
    smcState.write(raf, indent);
    // raf.writeStringSync(';\n');

    var ancestor = stateMachine.oldestAncestor(stateMachine.initialState);

    raf.writeStringSync('initial => ${ancestor.toString()} : ${stateMachine.initialStateLabel};\n');

    raf.closeSync();
  }
}
