import 'dart:io';

import 'package:fsm2/src/visualise/svg_file.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('fsm2-svg-test-');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  List<String> entries() => temp
      .listSync(followLinks: false)
      .map((entry) => p.basename(entry.path))
      .toList();

  test('replace preserves a victim linked from the old backup path', () async {
    final output = File(p.join(temp.path, 'report.svg'))
      ..writeAsStringSync('old old\r\n\r\nlast old');
    final victim = File(p.join(temp.path, 'victim'))
      ..writeAsStringSync('keep me');
    final backup = Link('${output.path}.bak')..createSync(victim.path);

    await SvgFile(output.path).replace(output.path, 'old', 'new');

    expect(victim.readAsStringSync(), 'keep me');
    expect(backup.targetSync(), victim.path);
    expect(output.readAsStringSync(), 'new new\n\nlast new\n');
    expect(
        entries(), unorderedEquals(['report.svg', 'report.svg.bak', 'victim']));
  }, skip: Platform.isWindows);

  test('replace replaces an output symlink and preserves its target', () async {
    final victim = File(p.join(temp.path, 'victim'))
      ..writeAsStringSync('old\n');
    final output = Link(p.join(temp.path, 'report.svg'))
      ..createSync(victim.path);

    await SvgFile(output.path).replace(output.path, 'old', 'new');

    expect(victim.readAsStringSync(), 'old\n');
    expect(FileSystemEntity.typeSync(output.path, followLinks: false),
        FileSystemEntityType.file);
    expect(File(output.path).readAsStringSync(), 'new\n');
    expect(entries(), unorderedEquals(['report.svg', 'victim']));
  }, skip: Platform.isWindows);

  test('replace cleans staging when destination cannot be replaced', () async {
    final source = File(p.join(temp.path, 'source.svg'))
      ..writeAsStringSync('old\n');
    final destination = Directory(p.join(temp.path, 'report.svg'))
      ..createSync();
    final child = File(p.join(destination.path, 'keep'))
      ..writeAsStringSync('keep me');

    await expectLater(
        SvgFile(source.path).replace(destination.path, 'old', 'new'),
        throwsA(isA<FileSystemException>()));

    expect(source.readAsStringSync(), 'old\n');
    expect(child.readAsStringSync(), 'keep me');
    expect(entries(), unorderedEquals(['source.svg', 'report.svg']));
  });

  test('replace preserves an empty file and cleans staging', () async {
    final output = File(p.join(temp.path, 'report.svg'))..writeAsStringSync('');

    await SvgFile(output.path).replace(output.path, 'old', 'new');

    expect(output.readAsStringSync(), isEmpty);
    expect(entries(), ['report.svg']);
  });

  for (final renameFails in [false, true]) {
    test(
        'cleanup failure does not mask ${renameFails ? 'rename failure' : 'success'}',
        () async {
      final source = File(p.join(temp.path, 'source.svg'))
        ..writeAsStringSync('old\n');
      final destination = p.join(temp.path, 'report.svg');
      if (renameFails) {
        Directory(destination).createSync();
      }
      final staging = temp.createTempSync('.fsm2-svg-');
      final cleanupFailure = StateError('simulated cleanup failure');
      final stagedDirectory =
          _ReplacementDirectory(staging.path, cleanupFailure: cleanupFailure);
      final parentDirectory =
          _ReplacementDirectory(temp.path, staging: stagedDirectory);

      await IOOverrides.runZoned(() async {
        final replace = SvgFile(source.path).replace(destination, 'old', 'new');
        if (renameFails) {
          await expectLater(replace, throwsA(isA<FileSystemException>()));
        } else {
          await replace;
          expect(File(destination).readAsStringSync(), 'new\n');
        }
      }, createDirectory: (_) => parentDirectory);

      expect(stagedDirectory.cleanupAttempted, isTrue);
      expect(source.readAsStringSync(), 'old\n');
      if (renameFails) {
        expect(
            File(p.join(staging.path, 'replacement.svg')).existsSync(), isTrue);
      }
    });
  }
}

// Override only the directory operations used by replace; file writes and
// renames still use the real filesystem.
class _ReplacementDirectory implements Directory {
  @override
  final String path;
  final Directory? staging;
  final Object? cleanupFailure;
  bool cleanupAttempted = false;

  _ReplacementDirectory(this.path, {this.staging, this.cleanupFailure});

  @override
  Future<Directory> createTemp([String? prefix]) async => staging!;

  @override
  Future<Directory> delete({bool recursive = false}) async {
    cleanupAttempted = true;
    throw cleanupFailure!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
