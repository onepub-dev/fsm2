import 'dart:io';

import 'package:fsm2/src/util/file_util.dart';
import 'package:fsm2/src/visualise/smcat_file.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('canonical positive page suffixes are extracted and removed', () {
    expect(getBasename('report.1.smcat'), 'report');
    expect(extractPageNo('report.1.smcat'), 1);
    expect(getBasename('report.notes.12.smcat'), 'report.notes');
    expect(extractPageNo('report.notes.12.smcat'), 12);
    expect(getBasename('report.smcat'), 'report');
    expect(extractPageNo('report.smcat'), 0);
  });

  for (final suffix in [
    'notes',
    '0',
    '00',
    '01',
    '+1',
    '-1',
    ' 1',
    '1 ',
    '0x1',
    '9223372036854775808',
    '999999999999999999999999999999999999',
  ]) {
    test('noncanonical suffix "$suffix" remains part of the basename', () {
      final filename = p.join('folder.2', 'report.$suffix.smcat');
      expect(getBasename(filename), 'report.$suffix');
      expect(extractPageNo(filename), 0);
    });
  }

  test('distinct smcat names produce distinct svg paths', () {
    final temp = Directory.systemTemp.createTempSync('fsm2-path-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final names = [
      'report',
      'report.notes',
      'report.0',
      'report.01',
      'report.+1',
      'report.-1',
      'report.1',
      'report.notes.1',
      'report.9223372036854775808',
    ];
    final paths = names
        .map((name) => SMCatFile(p.join(temp.path, '$name.smcat')).svgPath)
        .toList();

    expect(paths, names.map((name) => p.join(temp.path, '$name.svg')).toList());
    expect(paths.toSet(), hasLength(names.length));
  });
}
