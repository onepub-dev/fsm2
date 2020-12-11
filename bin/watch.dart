import 'dart:async';

import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';

import 'fsm2.dart';

var _controller = StreamController<FileSystemEvent>();

final lock = Lock();

Future<void> watchFiles(List<String> files) async {
  StreamSubscription<FileSystemEvent> subscriber;
  subscriber = _controller.stream.listen((event) async {
    // serialise the events
    // otherwise we end up trying to move multiple files
    // at once and that doesn't work.
    subscriber.pause();
    onFileSystemEvent(event);
    subscriber.resume();
  });

  /// start a watch on every subdirectory of _projectRoot
  for (final file in files) {
    watchFile(file);
  }

  final forever = Completer<void>();

  forever.future.whenComplete(() => subscriber.cancel());

  // wait until someone does ctrl-c.
  await forever.future;
}

void watchFile(String file) {
  File(file)
      .watch(events: FileSystemEvent.all)
      .listen((event) => _controller.add(event));
}

void watchDirectory(String projectRoot) {
  // ignore: avoid_print
  print('watching $projectRoot');
  Directory(projectRoot)
      .watch(events: FileSystemEvent.all)
      .listen((event) => _controller.add(event));
}

void onFileSystemEvent(FileSystemEvent event) {
  if (event is FileSystemCreateEvent) {
    onCreateEvent(event);
  } else if (event is FileSystemModifyEvent) {
    onModifyEvent(event);
  } else if (event is FileSystemMoveEvent) {
    onMoveEvent(event);
  } else if (event is FileSystemDeleteEvent) {
    onDeleteEvent(event);
  }
}

/// when we see a mod we want to delay the generation as we often
/// see multiple modifications when a file is being updated.
var _toGenerate = <String>[];

void onModifyEvent(FileSystemModifyEvent event) {
  _toGenerate.add(event.path);

  Future.delayed(const Duration(microseconds: 1500), () => delayedGeneration());
}

void delayedGeneration() {
  lock.synchronized(() {
    for (final file in _toGenerate.toSet()) {
      generate(file, show: true);
    }
    _toGenerate.clear();
  });
}

void onCreateEvent(FileSystemCreateEvent event) {
  if (event.isDirectory) {
    Directory(event.path)
        .watch(events: FileSystemEvent.all)
        .listen((event) => _controller.add(event));
  } else {
    if (lastDeleted != null) {
      if (basename(event.path) == basename(lastDeleted)) {
        // ignore: avoid_print
        print(red('Move from: $lastDeleted to: ${event.path}'));
        generate(event.path, show: true);
        lastDeleted = null;
      } else {
        generate(event.path, show: true);
      }
    }
  }
}

String lastDeleted;

void onDeleteEvent(FileSystemDeleteEvent event) {
  // ignore: avoid_print
  print('Delete:  ${event.path}');
  if (!event.isDirectory) {
    lastDeleted = event.path;
  }
}

void onMoveEvent(FileSystemMoveEvent event) {
  // var actioned = false;

  // var from = event.path;
  // var to = event.destination;

  // if (event.isDirectory) {
  //   actioned = true;
  //   await MoveCommand().importMoveDirectory(from: libRelative(from), to: libRelative(to), alreadyMoved: true);
  // } else {
  //   if (extension(from) == '.dart') {
  //     /// we don't process the move if the 'to' isn't a dart file.
  //     /// e.g. ignore a target of <lib>.dart.bak
  //     if (isDirectory(to) || isFile(to) && extension(to) == '.dart') {
  //       actioned = true;
  //       await MoveCommand()
  //           .moveFile(from: libRelative(from), to: libRelative(to), fromDirectory: false, alreadyMoved: true);
  //     }
  //   }
  // }
  // if (actioned) {
  //   print('Move: directory: ${event.isDirectory} ${event.path} destination: ${event.destination}');
  // }
}
