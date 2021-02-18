import 'dart:async';
import 'dart:developer';

import 'dart:io';

import 'package:path/path.dart' as p;

enum FolderChangeAction { create, modify, move, delete }

typedef OnFolderChanged = void Function(
    String pathTo, FolderChangeAction changeType);

/// Used to manage/monitor a folder containing files with the given extension.
///
class WatchFolder {
  String pathTo;
  String extension;

  bool recursive;

  OnFolderChanged onChanged;

  /// The file [extension] to filter what we are interested in.
  /// The [extension] should NOT start with a period.
  WatchFolder(
      {required this.pathTo,
      required this.extension,
      this.recursive = false,
      required this.onChanged});

  /// Watches the folder for any changes which involve a file ending
  /// in .[extension]
  void watch() {
    // ignore: avoid_print
    log('watching $pathTo');
    Directory(pathTo).watch().listen((event) {
      _controller.add(event);
    });

    _startDispatcher();
  }

  final _controller = StreamController<FileSystemEvent>();
  late StreamSubscription<FileSystemEvent> subscriber;

  Future<void> _startDispatcher() async {
    subscriber = _controller.stream.listen((event) async {
      // serialise the events
      // otherwise we end up trying to move multiple files
      // at once and that doesn't work.
      subscriber.pause();
      onFileSystemEvent(event);
      subscriber.resume();
    });
  }

  /// Call this method to stop watching a folder.
  void stop() {
    subscriber.cancel();
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

  void onCreateEvent(FileSystemCreateEvent event) {
    if (recursive && event.isDirectory) {
      Directory(event.path).watch().listen((event) => _controller.add(event));
    } else {
      // if (lastDeleted != null) {
      //   if (basename(event.path) == basename(lastDeleted)) {
      //     // print(red('Move from: $lastDeleted to: ${event.path}'));
      //     onChanged(event.path, FolderChangeType.move);
      //     lastDeleted = null;
      //   } else {
      _onChanged(event.path, FolderChangeAction.create);
      // }
    }
  }

  void onModifyEvent(FileSystemModifyEvent event) {
    _onChanged(event.path, FolderChangeAction.modify);
  }

  // String lastDeleted;

  void onDeleteEvent(FileSystemDeleteEvent event) {
    // // ignore: avoid_print
    // print('Delete:  ${event.path}');
    // if (!event.isDirectory) {
    //   lastDeleted = event.path;
    // }

    _onChanged(event.path, FolderChangeAction.delete);
  }

  void onMoveEvent(FileSystemMoveEvent event) {
    _onChanged(event.path, FolderChangeAction.move);
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

  void _onChanged(String path, FolderChangeAction type) {
    if (p.extension(path) == '.$extension') {
      onChanged(path, type);
    }
  }
}
