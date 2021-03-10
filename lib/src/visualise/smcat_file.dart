import 'dart:convert';
import 'dart:io';

import 'package:fsm2/src/util/file_util.dart';
import 'package:fsm2/src/visualise/progress.dart';
import 'package:fsm2/src/visualise/svg_file.dart';
import 'package:path/path.dart' as p;

class SMCatFile {
  String pathTo;
  int pageNo = 0;

  late SvgFile _svgFile;

  SMCatFile(this.pathTo) {
    pageNo = extractPageNo(pathTo);

    _svgFile = SvgFile(svgPath);
  }

  String get svgPath {
    final basename = getBasename(pathTo);
    if (pageNo == 0) {
      return '${p.join(p.dirname(pathTo), basename)}.svg';
    } else {
      return '${p.join(p.dirname(pathTo), basename)}.$pageNo.svg';
    }
  }

  SvgFile get svgFile {
    return _svgFile;
  }

  int? get height => svgFile.height;

  int? get width => svgFile.width;

  /// creates an Svg image from the smcat file.
  ///
  /// Requires that the 'smcat' cli tools are installed.
  ///
  /// Throws [SMCatException if the conversion fails]
  ///
  Future<SvgFile> convert({Progress? progress}) async {
    /// default no op progress
    progress ??= noOp;

    if (!isConversionRequired()) return svgFile;

    progress('Generating: $svgPath ');
    if (File(svgPath).existsSync()) {
      File(svgPath).deleteSync();
    }

    final Process process = await Process.start('smcat', [p.basename(pathTo)],
        workingDirectory: p.dirname(pathTo));

    process.stdout.transform(utf8.decoder).listen((data) {
      progress!(data);
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      if (!data.contains('viz.js:33')) progress!(data);
    });

    final int exitCode = await process.exitCode;

    if (exitCode == 0) {
      /// See if the filename contains a page no.
      progress('Generation of $svgPath complete.');
      _svgFile = SvgFile(svgPath);
      await _svgFile.addPageNo();
      return _svgFile;
    } else {
      progress('Generation of $svgPath failed.');
      throw SMCatException(
          'Generation of $svgPath failed. exitCode: $exitCode');
    }
  }

  int compareTo(SMCatFile other) {
    return pageNo - other.pageNo;
  }

  @override
  String toString() => pathTo;

  bool isConversionRequired() {
    final smc = FileStat.statSync(pathTo).modified;

    if (exists(svgPath)) {
      final svg = FileStat.statSync(svgPath).modified;
      return smc.isAfter(svg);
    }
    return true;
  }
}

class SMCatException implements Exception {
  String message;
  SMCatException(this.message);

  @override
  String toString() => message;
}
