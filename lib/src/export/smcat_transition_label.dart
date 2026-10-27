/// Serializes a label using state-machine-cat's transitionstring grammar.
///
/// https://github.com/sverweij/state-machine-cat/blob/main/src/parse/smcat/smcat-parser.peggy
///
/// Preserve unquoted labels unless they contain a separator or could be parsed
/// as a quoted string or leading comment. Quoted labels only escape double
/// quotes: JSON-style backslash or newline escaping would change the label.
String smcatTransitionLabel(String label) {
  // Reject malformed UTF-16 before UTF-8 file writing can replace its contents.
  for (var index = 0; index < label.length; index++) {
    final unit = label.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (index + 1 == label.length ||
          label.codeUnitAt(index + 1) < 0xdc00 ||
          label.codeUnitAt(index + 1) > 0xdfff) {
        throw ArgumentError(
            'SMCAT transition labels must contain valid Unicode.');
      }
      index++;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw ArgumentError(
          'SMCAT transition labels must contain valid Unicode.');
    }
  }

  final leading = label.replaceFirst(RegExp(r'^[ \t\r\n]*'), '');
  final needsQuoting = label.contains(';') ||
      label.contains('{') ||
      leading.startsWith('"') ||
      leading.startsWith('//') ||
      leading.startsWith('/*');
  if (!needsQuoting) {
    return label;
  }
  // The quoted grammar consumes a final backslash together with the closing
  // quote. Ordinary unquoted labels may safely end in a backslash.
  if (label.endsWith(r'\')) {
    throw ArgumentError(
        'SMCAT transition labels requiring quotes cannot end in a backslash.');
  }
  return '"${label.replaceAll('"', r'\"')}"';
}
