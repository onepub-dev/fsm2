import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:fsm2/src/util/file_util.dart' as u;
import 'package:fsm2/src/visualise/progress.dart';
import 'package:fsm2/src/visualise/svg_file.dart';
import 'package:fsm2/src/visualise/watch_folder.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

import 'smcat_file.dart';

/// Used to manage/monitor a folder containing smcat files.
///
class SMCatFolder {
  String folderPath;
  String basename;

  /// [folderPath] is the name of the folder holding the smcat files.
  SMCatFolder({required this.folderPath, required this.basename});

  final lock = Lock();

  /// We add an event each time an SvgFile is generated.
  final _generatedController = StreamController<SvgFile>();

  /// when we see a mod we want to delay the generation as we often
  /// see multiple modifications when a file is being updated.
  final _toGenerate = <SMCatFile>[];

  /// returns the list of smcat files in this folder that match
  /// the passed basename.
  List<SMCatFile> get list {
    final all = Directory(folderPath).listSync();

    final matching = <SMCatFile>[];

    for (final one in all) {
      final file = one.path;
      if (p.extension(file) == '.smcat' && getBasename(file) == basename) {
        matching.add(SMCatFile(file));
      }
    }

    matching.sort((lhs, rhs) => lhs.compareTo(rhs));

    return matching;
  }

  /// returns the list of svg files in this folder that match
  /// the passed basename.
  List<SvgFile> get listSvgs {
    final smcats = list;

    final List<SvgFile> found = <SvgFile>[];

    for (final smcat in smcats) {
      if (u.exists(smcat.svgPath)) {
        found.add(SvgFile(smcat.svgPath));
      }
    }
    return found;
  }

  void watch() {
    WatchFolder(
        pathTo: folderPath,
        extension: 'smcat',
        onChanged: (pathTo, action) => _onChanged(pathTo, action));
  }

  /// returns a stream of SvgFile. An SvgFile is added to the
  /// stream each time it is generated.  A single SvgFile
  /// will be generated each time you change the smcat file
  /// or call [queueGeneration]
  Stream<SvgFile> get stream => _generatedController.stream;

  void delayedGeneration() {
    lock.synchronized(() async {
      final files = _toGenerate.toSet().toList();
      files.sort((lhs, rhs) => lhs.compareTo(rhs));
      for (final file in files) {
        try {
          final svgFile = await file.convert(progress: (line) => log(line));
          _generatedController.add(svgFile);
        } on SMCatException catch (e, _) {
          /// already logged.
        }
      }
      _toGenerate.clear();
    });
  }

  void _onChanged(String file, FolderChangeAction action) {
    if (action != FolderChangeAction.delete) {
      queueGeneration(SMCatFile(file));
    }
  }

  /// Used by the watch mechanism to queue a smcat file for conversion to an svg file.
  ///
  /// You can however also queue files for generation via this mechanism.
  void queueGeneration(SMCatFile smCatFile) {
    _toGenerate.add(smCatFile);

    Future.delayed(
        const Duration(microseconds: 1500), () => delayedGeneration());
  }

  /// Generate the svg files for all smcat files in [folderPath] with a matching [basename]
  ///
  /// Throws [SMCatException] if the file does not exist.
  Future<void> generateAll({Progress? progress}) async {
    // progress ??= noOp;
    final files = await Directory(folderPath).list().toList();

    for (final entity in files) {
      final file = entity.path;
      if (getBasename(file) == basename && p.extension(file) == '.smcat') {
        await SMCatFile(file).convert(progress: progress);
      }
    }
  }

  static String getBasename(String file) => u.getBasename(file);

  Future<void> show({Progress? progress}) async {
    final files = await Directory(folderPath).list().toList();

    for (final entity in files) {
      final file = entity.path;
      if (p.extension(file) == 'svg') {
        await SvgFile(file).show(progress: (line) => progress!(line));
      }
    }
  }
}
