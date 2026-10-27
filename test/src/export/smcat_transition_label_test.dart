import 'dart:io';

import 'package:fsm2/fsm2.dart';
import 'package:fsm2/src/export/smcat_transition_label.dart';
import 'package:fsm2/src/types.dart' show TerminalState;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('SMCAT transition label serialization', () {
    for (final label in [
      '',
      'Started',
      'Next [ready]/run',
      'say "hello"',
      r'path\file',
      r'before\"after',
      'Ready 😀',
      'end\\',
      'end\\\\',
      'end\\\\\\',
      'ok\nInjected => Other',
      'ok // comment',
      'ok /* comment */',
      'ok } Other => State',
    ]) {
      test('preserves benign unquoted label ${label.codeUnits}', () {
        expect(smcatTransitionLabel(label), label);
      });
    }

    final quotedCases = <String, String>{
      'ok; Injected => Other;': '"ok; Injected => Other;"',
      'ok { nested }': '"ok { nested }"',
      'ok\nInjected => Other;': '"ok\nInjected => Other;"',
      '// comment\r\n/* comment */': '"// comment\r\n/* comment */"',
      '"hello"': r'"\"hello\""',
      ' \t\r\n"hello"': '" \t\r\n\\"hello\\""',
      ' \t\r\n// comment': '" \t\r\n// comment"',
      ' \t\r\n/* comment */': '" \t\r\n/* comment */"',
      r'before\"after;': r'"before\\"after;"',
      'Ready 😀;': '"Ready 😀;"',
    };

    for (final entry in quotedCases.entries) {
      test('preserves ${entry.key}', () {
        final encoded = smcatTransitionLabel(entry.key);
        expect(encoded, entry.value);
        final (decoded, consumed) = _parseQuotedLabel(encoded);
        expect(decoded, entry.key);
        expect(consumed, encoded.length);
      });
    }

    for (final label in [
      'end;\\',
      'end{\\\\',
      '"end\\\\\\',
      '//end\\',
      ' /*end\\',
      '\ud800',
      '\udc00',
      '\ud800x',
    ]) {
      test('rejects unrepresentable code units ${label.codeUnits}', () {
        expect(() => smcatTransitionLabel(label), throwsArgumentError);
      });
    }
  });

  group('SMCAT export', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('fsm2-smcat-label-test-');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('preserves ordinary initial, condition and side effect labels',
        () async {
      final machine = await _machine(
          initialLabel: 'Start',
          conditionLabel: 'ready',
          sideEffectLabel: 'run');
      final output = File(p.join(temp.path, 'ordinary.smcat'));
      machine.export(output.path);

      final contents = output.readAsStringSync();
      expect(contents, contains('initial => First : Start;'));
      expect(contents, contains('First => Second : Next [ready]/run;'));
    });

    test('preserves ordinary labels ending in backslashes', () async {
      final machine =
          await _machine(initialLabel: 'Start\\', sideEffectLabel: 'run\\\\');
      final output = File(p.join(temp.path, 'backslash.smcat'));
      machine.export(output.path);

      final contents = output.readAsStringSync();
      expect(contents, contains('initial => First : Start\\;'));
      expect(contents, contains('First => Second : Next/run\\\\;'));
    });

    test('keeps structural characters inside initial and regular labels',
        () async {
      const payload = 'ok"; }\nInjected => Other; { // comment';
      final machine = await _machine(
          initialLabel: payload,
          conditionLabel: payload,
          sideEffectLabel: payload);
      final output = File(p.join(temp.path, 'structural.smcat'));
      machine.export(output.path);

      final contents = output.readAsStringSync();
      _expectTransitionLabel(contents, 'initial => First : ', payload);
      _expectTransitionLabel(
          contents, 'First => Second : ', 'Next [$payload]/$payload');
      expect(
          contents,
          contains('initial => First : '
              '"ok\\"; }\nInjected => Other; { // comment";'));
      expect(
          contents,
          contains('First => Second : '
              '"Next [ok\\"; }\nInjected => Other; { // comment]'
              '/ok\\"; }\nInjected => Other; { // comment";'));
    });

    test('validates terminal transition labels attached to the virtual root',
        () async {
      final machine = await StateMachine.create((graph) => graph
        ..initialState<First>()
        ..state<First>((state) =>
            state.on<Next, TerminalState>(sideEffectLabel: 'end;\\')));
      final output = File(p.join(temp.path, 'terminal.smcat'))
        ..writeAsStringSync('keep existing contents');

      expect(() => machine.export(output.path), throwsArgumentError);
      expect(output.readAsStringSync(), 'keep existing contents');
    });

    for (final initial in [true, false]) {
      for (final invalid in ['end;\\', 'end{\\\\', '\ud800', '\udc00']) {
        test(
            'rejects ${initial ? 'initial' : 'regular'} invalid label '
            '${invalid.codeUnits} before opening output', () async {
          final machine = await _machine(
              initialLabel: initial ? invalid : 'Start',
              sideEffectLabel: initial ? 'run' : invalid);
          final output = File(p.join(temp.path, 'existing.smcat'))
            ..writeAsStringSync('keep existing contents');

          expect(() => machine.export(output.path), throwsArgumentError);
          expect(output.readAsStringSync(), 'keep existing contents');

          final absent = File(p.join(temp.path, 'absent.smcat'));
          expect(() => machine.export(absent.path), throwsArgumentError);
          expect(absent.existsSync(), isFalse);
        });
      }
    }
  });
}

void _expectTransitionLabel(String contents, String prefix, String expected) {
  final start = contents.indexOf(prefix);
  expect(start, isNonNegative);
  final source = contents.substring(start + prefix.length);
  final (decoded, consumed) = _parseQuotedLabel(source);
  expect(decoded, expected);
  expect(source.substring(consumed), startsWith(';\n'));
}

// The upstream quotedstring rule consumes backslash + quote as a pair, accepts
// other characters literally (including newlines), and stops at a bare quote:
// https://github.com/sverweij/state-machine-cat/blob/main/src/parse/smcat/smcat-parser.peggy
(String, int) _parseQuotedLabel(String source) {
  if (!source.startsWith('"')) {
    throw const FormatException('Expected a quoted transition label');
  }
  final decoded = StringBuffer();
  var index = 1;
  while (index < source.length) {
    final character = source[index++];
    if (character == '"') {
      return (decoded.toString(), index);
    }
    if (character == r'\' && index < source.length && source[index] == '"') {
      decoded.write('"');
      index++;
    } else {
      decoded.write(character);
    }
  }
  throw const FormatException('Unterminated transition label');
}

Future<StateMachine> _machine(
        {required String initialLabel,
        String? conditionLabel,
        String? sideEffectLabel}) =>
    StateMachine.create((graph) => graph
      ..initialState<First>(label: initialLabel)
      ..state<First>((state) => state.on<Next, Second>(
          conditionLabel: conditionLabel, sideEffectLabel: sideEffectLabel))
      ..state<Second>((state) {}));

class First implements State {}

class Second implements State {}

class Next implements Event {}
