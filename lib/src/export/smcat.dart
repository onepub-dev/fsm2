import 'package:path/path.dart';
import 'package:tree_iterator/tree_iterator.dart';

import '../state_machine.dart';
import 'exporter.dart';
import 'smc_state.dart';
import 'smc_transition.dart';

/// Class exports a [StateMachine] to a state-machine-cat notation
///  file so that the FMS can be visualised.
///
/// https://github.com/sverweij/state-machine-cat
///
/// You can visualise your statemachine online
///
/// https://state-machine-cat.js.org
///
/// state-machine-cat has cli tools which you can use during development:
///
/// npm install --global state-machine-cat
///
/// To visualise the resulting file graph run:
///
/// ``` bash
/// run: smcat <path>
/// ```

class SMCatExporter implements Exporter {
  final StateMachine stateMachine;

  final virtualRoot = SMCState.root(name: 'initial', pageBreak: false);

  /// we need to suppress any duplicate transitions which can
  /// happen when we are forking.
  final seenTransitions = <SMCTransition>{};

  final exports = ExportedPages();

  /// creates a map of the terminal ordinals to what
  /// parent state they belong to.
  /// ```dart
  /// var terminalsOwnedByRegion = <Type, List<int>>{};
  /// ```
  SMCatExporter(this.stateMachine);

  ExportedPages export(String path) => _save(path);

  ExportedPages _save(String path) {
    final smcRoot = _build();

    _openPageFiles(smcRoot, path);

    const indent = 0;
    smcRoot.write(this, indent: indent);

    final ancestor = oldestAncestor(stateMachine, stateMachine.initialState);

    write('initial => $ancestor : ${stateMachine.initialStateLabel};',
        page: 0, indent: 0, endOfLine: true);

    _closePageFiles();

    return exports;
  }

  SMCState _build() {
    virtualRoot.pageNo = 0;
    for (final child in stateMachine.topStateDefinitions) {
      virtualRoot
          .addChild(SMCState.child(parent: virtualRoot, sd: child, pageNo: 0));
    }

    // we can only build the transitions once the full
    // statemachine tree is built.
    traverseTree<SMCState>(virtualRoot, (node) => node.children, (node) {
      node.buildTransitions(stateMachine);

      return true;
    });

    /// now remove duplicates.
    /// We can't do this in the above traverseTree as transitions can be
    /// added to an ancestor so we can't see them easily
    ///
    ///
    traverseTree<SMCState>(virtualRoot, (node) => node.children, (node) {
      final toBeRemoved = <SMCTransition>[];

      /// mark any duplicate transitions.
      for (final transition in node.transitions) {
        if (seenTransitions.contains(transition)) {
          toBeRemoved.add(transition);
        } else {
          seenTransitions.add(transition);
        }
      }

      // remove any marked transitions.
      for (final transition in toBeRemoved) {
        node.transitions.remove(transition);
      }
      return true;
    });

    return virtualRoot;
  }

  void _closePageFiles() {
    for (final page in exports.pages) {
      page.close();
    }
  }

  void _openPageFiles(SMCState smcRoot, String filepath) {
    var pageBreaks = _countPageBreaks(smcRoot);

    if (pageBreaks == 0) {
      exports.add(filepath);
    } else {
      pageBreaks++;
      final ext = extension(filepath);
      final base = basenameWithoutExtension(filepath);
      final dir = dirname(filepath);
      for (var i = 1; i <= pageBreaks; i++) {
        exports.add('${join(dir, base)}.$i$ext');
      }
    }
  }

  int _countPageBreaks(SMCState smcRoot) {
    var pageBreaks = 0;

    if (smcRoot.pageBreak) {
      pageBreaks++;
    }
    for (final child in smcRoot.children) {
      pageBreaks += _countPageBreaks(child);
    }
    return pageBreaks;
  }

  /// writes a string to the given page file.
  @override
  void write(String string,
      {required int indent, required int? page, bool endOfLine = false}) {
    exports.write(page!, '\n${_indent(indent)}$string');
    if (endOfLine) {
      exports.write(page, '\n');
    }
  }

  /// writes a string to the given page file.
  @override
  void append(String string, {required int? page, bool endOfLine = false}) {
    exports.write(page!, string);

    if (endOfLine) {
      exports.write(page, '\n');
    }
  }

  String _indent(int level) => '\t' * (level - 1);
}
