import 'package:fsm2/src/state_machine.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'exporter.dart';
import 'smc_state.dart';

/// Class exports a [StateMachine] to a state-machine-cat notation file so that the FMS can be visualised.
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
/// ```
/// run: smcat <path>
/// ```

class SMCatExporter implements Exporter {
  final StateMachine stateMachine;
  final SMCState virtualRoot = SMCState(name: 'initial', type: SMCStateType.root, pageBreak: false);

  final exports = ExportedPages();

  /// creates a map of the terminal ordinals to what
  /// parent state they belong to.
  /// var terminalsOwnedByRegion = <Type, List<int>>{};
  SMCatExporter(this.stateMachine);

  ExportedPages export(String path) {
    return _save(path);
  }

  ExportedPages _save(String path) {
    var smcRoot = _build();

    _openPageFiles(smcRoot, path);

    var indent = 0;
    smcRoot.write(this, indent: indent, page: 0);
    // raf.writeStringSync(';\n');

    var ancestor = stateMachine.oldestAncestor(stateMachine.initialState);

    write('initial => ${ancestor.toString()} : ${stateMachine.initialStateLabel};',
        page: 0, indent: 0, endOfLine: true);

    _closePageFiles();

    return exports;
  }

  SMCState _build() {
    for (var child in stateMachine.topStateDefinitions) {
      virtualRoot.addChild(SMCState.build(virtualRoot, child));
    }

    return virtualRoot;
  }

  void _closePageFiles() {
    for (var page in exports.pages) {
      page.close();
    }
  }

  void _openPageFiles(SMCState smcRoot, String filepath) {
    var pageBreaks = _countPageBreaks(smcRoot);

    if (pageBreaks == 0) {
      exports.add(filepath);
    } else {
      pageBreaks++;
      var ext = extension(filepath);
      var base = basenameWithoutExtension(filepath);
      var dir = dirname(filepath);
      for (var i = 1; i <= pageBreaks; i++) {
        exports.add('${join(dir, base)}.$pageBreaks$ext');
      }
    }
  }

  int _countPageBreaks(SMCState smcRoot) {
    var pageBreaks = 0;

    if (smcRoot.pageBreak) pageBreaks++;
    for (var child in smcRoot.children) {
      pageBreaks += _countPageBreaks(child);
    }
    return pageBreaks;
  }

  /// writes a string to the given page file.
  @override
  void write(String string, {@required int indent, @required int page, bool endOfLine = false}) {
    exports.write(page, '\n${_indent(indent)}$string');
    if (endOfLine) exports.write(page, '\n');
  }

  /// writes a string to the given page file.
  @override
  void append(String string, {@required int page, bool endOfLine = false}) {
    exports.write(page, string);

    if (endOfLine) exports.write(page, '\n');
  }

  String _indent(int level) {
    return '\t' * (level - 1);
  }
}
