#! /usr/bin/env dcli

import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:fsm2/src/visualise/smcat_folder.dart';
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
    /// Settings().setVerbose(enabled: true);
  }

  if (parsed.wasParsed('install')) {
    install();
    exit(0);
  }

  if (parsed.rest.length != 1) {
    print(red(
        'You must pass a to path the basename of the smcat file. e.g. test/life_cycle'));
    showUsage(parser);
  }
  final pathTo = parsed.rest[0];
  final folder =
      SMCatFolder(folderPath: dirname(pathTo), basename: getBasename(pathTo));

  await folder.generateAll();

  if (parsed.wasParsed('watch')) {
    folder.watch();
  }

  if (parsed.wasParsed('show')) {
    folder.watch();
  }
}

void install() {
  if (which('npm').notfound) {
    print(red('Please install npm and then try again'));
    exit(1);
  }
  'npm install --global state-machine-cat'.start(privileged: true);
}

void showUsage(ArgParser parser) {
  print('Usage: ${Script.current.exeName} <base name of myfsm2>\n');
  print('Converts a set of smcat files into svg files.');
  print(
      'If your smcat file has multiple parts due to page breaks then each page will be processed.');
  print(parser.usage);
  exit(1);
}

String getBasename(String pathTo) {
  var basename = basenameWithoutExtension(pathTo);
  if (basename.contains('.')) {
    basename = basenameWithoutExtension(pathTo);
  }
  return basename;
}
