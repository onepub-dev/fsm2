// part of our public api
// ignore_for_file: omit_obvious_property_types

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/file_util.dart';
import 'progress.dart';
import 'svg_file.dart';

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

  SvgFile get svgFile => _svgFile;

  int get height => svgFile.height;

  int get width => svgFile.width;

  /// creates an Svg image from the smcat file.
  ///
  /// Requires that the 'smcat' cli tools are installed.
  ///
  /// If [force] is true, the conversion will be performed even if the
  /// svg file already exists.
  ///
  /// Throws [SMCatException if the conversion fails]
  ///
  Future<SvgFile> convert(
      {required bool force, Progress progress = noOp}) async {
    if (!force && !isConversionRequired()) {
      return svgFile;
    }

    progress('Generating: $svgPath ');
    if (File(svgPath).existsSync()) {
      File(svgPath).deleteSync();
    }

    final process = await Process.start('smcat', [p.basename(pathTo)],
        workingDirectory: p.dirname(pathTo));

    process.stdout.transform(utf8.decoder).listen((data) {
      progress(data);
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      if (!data.contains('viz.js:33')) {
        progress(data);
      }
    });

    final exitCode = await process.exitCode;

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

  int compareTo(SMCatFile other) => pageNo - other.pageNo;

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
