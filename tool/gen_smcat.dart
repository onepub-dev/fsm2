#! /usr/bin/env dcli

import 'dart:io';
import 'package:dcli/dcli.dart';
import '../test/cleaning_air_test.dart';

/// dcli script generated by:
/// dcli create gen_smcat.dart
///
/// See
/// https://pub.dev/packages/dcli#-installing-tab-
///
/// For details on installing dcli.
///

void main(List<String> args) {
  var machine = createMachine();
  machine.export('clean_air.smcat');
}

void showUsage(ArgParser parser) {
  print('Usage: gen_smcat.dart -v -prompt <a questions>');
  print(parser.usage);
  exit(1);
}