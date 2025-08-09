import 'dart:io';

abstract class Exporter {
  /// writes to a new line by writting a leading \n
  /// and the writing [indent]  tabs.
  void write(String string,
      {required int indent, required int? page, bool endOfLine = false});

  /// append to an existing line
  void append(String string, {required int? page, bool endOfLine = false});
}

class ExportedPages {
  /// The set of page files that have been exported.
  final pages = <ExportedPage>[];

  void add(String file) {
    pages.add(ExportedPage(file));
  }

  void write(int page, String string) {
    pages[page].write(string);
  }
}

class ExportedPage {
  ExportedPage(this.path) {
    final file = File(path);
    raf = file.openSync(mode: FileMode.write);
  }
  final String path;
  late RandomAccessFile raf;

  void write(String string) {
    raf.writeStringSync(string);
  }

  void close() {
    raf.closeSync();
  }
}
