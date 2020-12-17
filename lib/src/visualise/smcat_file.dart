import 'dart:convert';
import 'dart:io';

import 'package:fsm2/src/util/file_util.dart';
import 'package:fsm2/src/visualise/progress.dart';
import 'package:fsm2/src/visualise/svg_file.dart';
import 'package:path/path.dart' as p;

class SMCatFile {
  String pathTo;
  int pageNo;

  String _svgPath;
  SMCatFile(this.pathTo) {
    pageNo = extractPageNo(pathTo);
  }

  String get svgPath {
    if (_svgPath == null) {
      final basename = getBasename(pathTo);
      if (pageNo == 0) {
        _svgPath = '${p.join(p.dirname(pathTo), basename)}.svg';
      } else {
        _svgPath = '${p.join(p.dirname(pathTo), basename)}.$pageNo.svg';
      }
    }
    return _svgPath;
  }

  /// creates an Svg image from the smcat file.
  ///
  /// Requires that the 'smcat' cli tools are installed.
  ///
  /// Throws [SMCatException if the conversion fails]
  ///
  Future<SvgFile> convert({Progress progress}) async {
    /// default no op progress
    progress ??= noOp;

    final basename = getBasename(pathTo);

    final outputFile = '$basename.svg';
    progress('Generating: $outputFile ');
    if (File(outputFile).existsSync()) {
      File(outputFile).deleteSync();
    }

    final Process process = await Process.start('smcat', [p.basename(pathTo)],
        workingDirectory: p.dirname(pathTo));

    process.stdout.transform(utf8.decoder).listen((data) {
      progress(data);
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      if (!data.contains('viz.js:33')) progress(data);
    });

    final int exitCode = await process.exitCode;

    if (exitCode == 0) {
      /// See if the filename contains a page no.
      progress('Generation of $svgPath complete.');
      final svgFile = SvgFile(svgPath);
      await svgFile.addPageNo();
      return svgFile;
    } else {
      progress('Generation of $outputFile failed.');
      throw SMCatException(
          'Generation of $outputFile failed. exitCode: $exitCode');
    }
  }

  int compareTo(SMCatFile other) {
    return pageNo - other.pageNo;
  }

  @override
  String toString() => pathTo;
}

class SMCatException implements Exception {
  String message;
  SMCatException(this.message);

  @override
  String toString() => message;
}
