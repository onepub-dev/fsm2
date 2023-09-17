#! /usr/bin/env dcli

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:dcli_terminal/dcli_terminal.dart';
import 'package:fsm2/src/util/file_util.dart';
import 'package:fsm2/src/visualise/smcat_folder.dart';
import 'package:fsm2/src/visualise/svg_file.dart';
import 'package:path/path.dart';

/// dcli create show.dart
///
/// See
/// https://pub.dev/packages/dcli#-installing-tab-
///
/// For details on installing dcli.
///
// ignore_for_file: avoid_print
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Logs additional details to the cli',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Shows the help message',
    )
    ..addFlag(
      'show',
      abbr: 's',
      negatable: false,
      help:
          'After generating the image file it will be displayed using firefox.',
    )
    ..addFlag(
      'watch',
      abbr: 'w',
      negatable: false,
      help: 'Monitors the smcat files and regenerates the svg if they change.',
    )
    ..addFlag(
      'install',
      abbr: 'i',
      negatable: false,
      help: 'Install the smcat dependencies',
    )
    ..addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Force regeneration of svg files even if they are upto date.',
    );

  final parsed = parser.parse(args);

  if (parsed.wasParsed('help')) {
    showUsage(parser);
  }

  if (parsed.wasParsed('verbose')) {
    await Settings().setVerbose(enabled: true);
  }

  if (parsed.wasParsed('install')) {
    await install();
    exit(0);
  }

  if (parsed.rest.length != 1) {
    print(red(
        'You must pass a to path the basename of the smcat file. e.g. test/life_cycle'));
    showUsage(parser);
  }

  final show = parsed.wasParsed('show');

  final watch = parsed.wasParsed('watch');

  final force = parsed.wasParsed('force');

  final pathTo = parsed.rest[0];
  final folder =
      SMCatFolder(folderPath: dirname(pathTo), basename: getBasename(pathTo));
  await generate(folder, show: show, watch: watch, force: force);
}

Future<void> generate(SMCatFolder folder,
    {required bool watch, required bool force, bool? show}) async {
  var count = 0;
  await folder.generateAll(
      force: force,
      progress: (line) {
        print(line);
        count++;
      });

  if (count == 0) {
    print('''
No files found that needed generating. Use -f to regenerate all files.''');
  }
  if (watch) {
    folder.watch();

    if (show!) {
      print(folder.listSvgs);
      await SvgFile.showList(folder.listSvgs, progress: print);
      await for (final svgFile in folder.stream) {
        await svgFile.show(progress: print);
      }
    }
  } else if (show!) {
    await folder.show(progress: print);
  }
}

Future<void> install() async {
  if ((await which('npm')).notfound) {
    print(red('Please install npm and then try again'));
    exit(1);
  }
  await Process.start('npm', ['install', '--global', 'state-machine-cat']);
}

void showUsage(ArgParser parser) {
  print('''
Usage: ${basename(Platform.executable)} <base name of myfsm2>
Converts a set of smcat files into svg files.
If your smcat file has multiple parts due to page breaks then each page will be processed.
${parser.usage}''');
  exit(1);
}
