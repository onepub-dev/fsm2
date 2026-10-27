import 'dart:io';

import 'package:path/path.dart' as p;

/// Returns the filename without its extension or a canonical page suffix.
String getBasename(String pathTo) {
  var basename = p.basenameWithoutExtension(pathTo);
  if (extractPageNo(pathTo) != 0) {
    basename = p.basenameWithoutExtension(basename);
  }
  return basename;
}

/// Extracts a page no from a file name of the form:
///
/// name.1.xxx
///
/// Only canonical positive integers are page numbers; otherwise 0 is returned.
///
int extractPageNo(String filename) {
  final extension = p.extension(p.basenameWithoutExtension(filename));

  if (!extension.startsWith('.')) {
    return 0;
  }
  final suffix = extension.substring(1);
  final pageNo = int.tryParse(suffix);
  if (pageNo == null || pageNo <= 0 || pageNo.toString() != suffix) {
    return 0;
  }
  return pageNo;
}

bool exists(String pathTo) => File(pathTo).existsSync();
