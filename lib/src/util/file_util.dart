import 'dart:io';

import 'package:path/path.dart' as p;

/// returns the filename without any extension and without a path.
String getBasename(String pathTo) {
  var basename = p.basenameWithoutExtension(pathTo);
  if (basename.contains('.')) {
    basename = p.basenameWithoutExtension(basename);
  }
  return basename;
}

/// Extracts a page no from a file name of the form:
///
/// name.1.xxx
///
/// If the filename doesn't contain a page no. then 0 is returned.
///
int extractPageNo(String filename) {
  final extension = p.extension(p.basenameWithoutExtension(filename));

  var nPageNo = 0;
  if (extension.startsWith('.')) {
    nPageNo = int.tryParse(extension.substring(1)) ?? 0;
  }

  return nPageNo;
}

bool exists(String pathTo) {
  return File(pathTo).existsSync();
}
