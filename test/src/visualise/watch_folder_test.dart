import 'dart:async';
import 'dart:developer';

import 'package:fsm2/src/visualise/watch_folder.dart';
import 'package:test/test.dart';

import '../../registration_test.dart' hide log;

/// This test doesn't work. We need some method to trigger the watch.
void main() {
  test('watch folder', () async {
    final done = Completer<bool>();

    var count = 0;

    WatchFolder(
        pathTo: 'test/smcat',
        extension: 'smcat',
        onChanged: (file, action) {
          log('$file $action');
          count++;

          if (count == 5) {
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
