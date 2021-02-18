import 'dart:async';
import 'dart:developer';

import 'package:dcli/dcli.dart';
import 'package:fsm2/src/visualise/watch_folder.dart';
import 'package:test/test.dart';

import '../../registration_test.dart' hide log;

void main() {
  test('watch folder', () async {
    final done = Completer<bool>();

    var count = 0;

    final files =
        find('registration.*.svg', workingDirectory: 'test/smcat').toList();
    for (final file in files) {
      delete(file);
    }

    /// The export should create 5 pages each in a separate file
    const expectedPageCount = 5;
    WatchFolder(
        pathTo: 'test/smcat',
        extension: 'smcat',
        onChanged: (file, action) {
          log('$file $action');
          count++;

          if (count == expectedPageCount) {
            done.complete(true);
          }
        });

    final fsm = createMachine();
    const file = 'test/smcat/registration.smcat';
    // var exports =
    fsm.export(file);

    await done.future;
  }, skip: true);
}
