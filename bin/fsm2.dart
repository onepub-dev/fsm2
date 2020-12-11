#! /usr/bin/env dcli

import 'dart:async';
import 'dart:io';
import 'package:dcli/dcli.dart';
import 'package:meta/meta.dart';

import 'watch.dart';

/// dcli create show.dart
///
/// See
/// https://pub.dev/packages/dcli#-installing-tab-
///
/// For details on installing dcli.
///
// ignore_for_file: avoid_print
Future<void> main(List<String> args) async {
  final parser = ArgParser();
  parser.addFlag(
    'verbose',
    abbr: 'v',
    negatable: false,
    help: 'Logs additional details to the cli',
  );

  parser.addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Shows the help message',
  );

  parser.addFlag(
    'show',
    abbr: 's',
    negatable: false,
    help: 'After generating the image file it will be displayed using firefox.',
  );

  parser.addFlag(
    'watch',
    abbr: 'w',
    negatable: false,
    help: 'Monitors the smcat files and regenerates the svg if they change.',
  );

  parser.addFlag(
    'install',
    abbr: 'i',
    negatable: false,
    help: 'Install the smcat dependencies',
  );

  final parsed = parser.parse(args);

  if (parsed.wasParsed('help')) {
    showUsage(parser);
  }

  if (parsed.wasParsed('verbose')) {
    Settings().setVerbose(enabled: true);
  }

  if (parsed.wasParsed('install')) {
    install();
    exit(0);
  }

  if (parsed.rest.isEmpty) {
    print(red('You must pass a to path the basename of the smcat file'));
    showUsage(parser);
  }

  await generateAll(parsed.rest,
      show: parsed.wasParsed('show'), watch: parsed.wasParsed('watch'));
}

Future<void> generateAll(List<String> rest, {bool show, bool watch}) async {
  final watchList = <String>[];

  for (var file in rest) {
    if (exists(file)) {
      watchList.add(file);
      generate(file, show: show);
    } else {
      /// if the passed file name had an extension
      /// then we do an exact match. So if we are
      /// here the file doesn't exist.
      if (extension(file).isNotEmpty) {
        printerr(red('File $file not found'));
        exit(1);
      }

      /// do a glob match as the filename didn't have an extension.
      var count = 0;
      final pattern = '$file.*.smcat';
      for (file in find(pattern, recursive: false).toList()) {
        generate(file, show: show);
        count++;
        watchList.add(file);
      }
      if (count == 0) {
        if (exists(file)) {
          generate(file, show: show);
          watchList.add(file);
        } else {
          printerr(orange(
              'No files found that match the pattern: ${truepath(pattern)}.'));
        }
      }
    }
  }
  if (watch && watchList.isNotEmpty) {
    await watchFiles(watchList);
  }
}

void install() {
  if (which('npm').notfound) {
    print(red('Please install npm and then try again'));
    exit(1);
  }
  'npm install --global state-machine-cat'.start(privileged: true);
}

void generate(String path, {@required bool show}) {
  final outputFile = '${basenameWithoutExtension(path)}.svg';
  print('Generating: $outputFile ');
  if (exists(outputFile)) {
    delete(outputFile);
  }

  /// 'smcat -T dot $path | dot -T svg > your-machine.svg'.run;
  final result = start('smcat $path',
      progress: Progress((stdout) => print(stdout), stderr: (stderr) {
        /// suppress the viz warning:
        /// https://github.com/sverweij/state-machine-cat/issues/127
        if (!stderr.contains('viz.js:33')) print(stderr);
      }),
      nothrow: true);

  if (result.exitCode == 0) {
    /// See if the filename contains a page no.
    var pageNo = extension(basenameWithoutExtension(path));
    if (pageNo.isNotEmpty) {
      pageNo = pageNo.substring(1);

      final page = int.tryParse(pageNo);
      if (page != null) {
        final svgPath =
            '${join(dirname(path), basenameWithoutExtension(path))}.svg';
        addPageNo(svgPath, page);
      }
    }
    if (show) {
      'firefox $outputFile'
          .start(detached: true, workingDirectory: dirname(path));
    }
    print('Generation of $outputFile complete.');
  } else {
    print(red('Generation of $outputFile failed.'));
  }
}

/// Add a page no. at the top of the page.
/// We add the svg elements at the very end of the file.
void addPageNo(String svgPath, int page) {
  addInkscapeNamespace(svgPath);

  final pageSize = getPageSize(svgPath);

  const xPos = 40;
  final yPos = pageSize.height + 20;
  final svgPageNo = '''
    <text
     xml:space="preserve"
     style="font-style:normal;font-weight:normal;font-size:30px;line-height:1.25;font-family:sans-serif;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.75"
     x="$xPos"
     y="$yPos"
     id="text288"><tspan
       sodipodi:role="line"
       id="tspan286"
       x="$xPos"
       y="$yPos"
       style="font-size:12px;stroke-width:0.75">Page: $page</tspan></text>
</svg>
''';

  replace(svgPath, '</svg>', svgPageNo);

  final newPageSize = Size.copyFrom(pageSize);
  newPageSize.height = yPos + 10;
  updatePageHeight(svgPath, pageSize, newPageSize);
}

/// We increase the page hieght so we can fit the page no. at the bottom of the
/// page without it being over any of the diagram.
void updatePageHeight(String svgPath, Size pageSize, Size newPageSize) {
  final existing =
      '<svg width="${pageSize.width}pt" height="${pageSize.height}';
  final replacement =
      '<svg width="${newPageSize.width}pt" height="${newPageSize.height}';
  replace(svgPath, existing, replacement);

  /// update the viewbox
  replace(svgPath, ' ${pageSize.height}.00"', ' ${newPageSize.height}.00"');
}

void addInkscapeNamespace(String svgPath) {
  const existing = 'xmlns="http://www.w3.org/2000/svg"';

  const replacement =
      'xmlns="http://www.w3.org/2000/svg" xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"';

  replace(svgPath, existing, replacement);
}

class Size {
  int width;
  int height;
  Size();
  Size.copyFrom(Size pageSize)
      : width = pageSize.width,
        height = pageSize.height;
}

/// gets the page height from the svg file.
Size getPageSize(String svgPath) {
  final size = Size();
  final svgLine = read(svgPath)
      .toList()
      .firstWhere((line) => line.startsWith('<svg width'));

  final attributes = svgLine.split(' ');
  assert(attributes.length == 3);

  final widthAttribute = attributes[1];
  assert(widthAttribute.startsWith('width'));
  size.width = getAttributeInt(widthAttribute);

  final heightAttribute = attributes[2];
  assert(heightAttribute.startsWith('height'));
  size.height = getAttributeInt(heightAttribute);

  return size;
}

int getAttributeInt(String attribute) {
  final parts = attribute.split('=');
  assert(parts.length == 2);
  var pts = parts[1];
  pts = pts.replaceAll('pt', '');
  pts = pts.replaceAll('"', '');

  return int.tryParse(pts);
}

void showUsage(ArgParser parser) {
  print('Usage: ${Script.current.exeName} <base name of myfsm2>\n');
  print('Converts a set of smcat files into svg files.');
  print(
      'If your smcat file has multiple parts due to page breaks then each page will be processed.');
  print(parser.usage);
  exit(1);
}
