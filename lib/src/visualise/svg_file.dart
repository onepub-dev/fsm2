import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:fsm2/src/util/file_util.dart';
import 'package:fsm2/src/visualise/progress.dart';
import 'package:path/path.dart';
import 'size.dart';

class SvgFile {
  String pathTo;

  int pageNo;

  Size _size;

  DateTime _lastModified;

  SvgFile(this.pathTo) {
    pageNo = extractPageNo(pathTo);
    lastModified;
  }

  bool get hasChanged {
    return _lastModified != lastModified;
  }

  int get width => size.width;

  int get height => size.height;

  void reload() {}

  Future<void> show({Progress progress}) async {
    progress ??= noOp;

    final filename = basename(pathTo);
    final workingDir = dirname(pathTo);

    final Process process = await Process.start('firefox', [filename],
        workingDirectory: workingDir, mode: ProcessStartMode.normal);

    process.stdout.transform(utf8.decoder).listen((data) {
      progress(data);
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      progress(data);
    });
  }

  DateTime get lastModified {
    if (_lastModified == null) {
      if (exists(pathTo)) {
        _lastModified = File(pathTo).lastModifiedSync();
      } else {
        _lastModified = DateTime.now().subtract(const Duration(days: 1000));
      }
    }

    return _lastModified;
  }

  /// Add a page no. at the top of the page.
  /// We add the svg elements at the very end of the file.
  Future<void> addPageNo() async {
    await _addInkscapeNamespace(pathTo);

    const xPos = 40;
    final yPos = size.height + 20;
    final svgPageNo = '''
    <text
     xml:space="preserve"
     style="font-style:normal;font-weight:normal;font-size:30px;line-height:1.25;font-family:sans-serif;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.75"
     x="$xPos"
     y="$yPos"
     id="text288"><tspan
       sodipodi:role="line"
       id="tspan286"
       x="$xPos"
       y="$yPos"
       style="font-size:12px;stroke-width:0.75">Page: $pageNo</tspan></text>
</svg>
''';

    await replace(pathTo, '</svg>', svgPageNo);

    final newPageSize = Size.copyFrom(size);
    newPageSize.height = yPos + 10;
    await updatePageHeight(pathTo, size, newPageSize);
  }

  /// We increase the page hieght so we can fit the page no. at the bottom of the
  /// page without it being over any of the diagram.
  Future<void> updatePageHeight(
      String svgPath, Size pageSize, Size newPageSize) async {
    final existing =
        '<svg width="${pageSize.width}pt" height="${pageSize.height}pt';
    final replacement =
        '<svg width="${newPageSize.width}px" height="${newPageSize.height}px';
    await replace(svgPath, existing, replacement);

    /// update the viewbox
    await replace(
        svgPath, ' ${pageSize.height}.00"', ' ${newPageSize.height}.00"');
  }

  Future<void> _addInkscapeNamespace(String svgPath) async {
    const existing = 'xmlns="http://www.w3.org/2000/svg"';

    const replacement =
        'xmlns="http://www.w3.org/2000/svg" xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"';

    await replace(svgPath, existing, replacement);
  }

  int compareTo(SvgFile other) {
    return pageNo - other.pageNo;
  }

  Size get size {
    return _size ??= _getPageSize();
  }

  /// gets the page height from the svg file.
  Size _getPageSize() {
    // print(
    //     'exists: ${exists(pathTo)} $pathTo size: ${FileStat.statSync(pathTo).size}');
    final size = Size(0, 0);
    final List<String> lines = load();
    final svgLine = lines.firstWhere(
        (line) => line.trim().startsWith('<svg width'),
        orElse: () => '<svg width="1000pt" height="500pt"');

    if (svgLine == '<svg width="1000pt" height="500pt"') {
      log('Invalid file as pages size not found');
      log(lines.join('\n'));
    }

    final attributes = svgLine.trim().split(' ');
    assert(attributes.length == 3);

    final widthAttribute = attributes[1];
    assert(widthAttribute.startsWith('width'));
    size.width = getAttributeInt(widthAttribute);

    final heightAttribute = attributes[2];
    assert(heightAttribute.startsWith('height'));
    size.height = getAttributeInt(heightAttribute);

    return size;
  }

  List<String> load() {
    var lines = <String>[];
    if (exists(pathTo)) {
      lines = File(pathTo).readAsLinesSync().toList();
    } else {
      lines = _empty.split('\n');
    }
    return lines;
  }

  int getAttributeInt(String attribute) {
    final parts = attribute.split('=');
    assert(parts.length == 2);

    var pts = parts[1];
    pts = pts.replaceAll('pt', '');
    pts = pts.replaceAll('px', '');
    pts = pts.replaceAll('"', '');

    return int.tryParse(pts);
  }

  @override
  int get hashCode => pathTo.hashCode;

  @override
  bool operator ==(covariant SvgFile other) {
    return pathTo == other.pathTo;
  }

  Future<void> replace(
      String svgPath, String existing, String replacement) async {
    return;
    try {
      log('replace on $svgPath');
      final svgFile = File(svgPath);
      final lines = load();

      final backupPath = '$svgPath.bak';
      final backupFile = File(backupPath);
      final backup = backupFile.openWrite(mode: FileMode.write);

      for (final line in lines) {
        backup.writeln(line.replaceAll(existing, replacement));
      }

      await backup.flush();
      await backup.close();

      svgFile.deleteSync();

      backupFile.renameSync(svgPath);
      log('replace complete $svgPath');
    } catch (e, st) {
      log('Excepton in replace: $e, $st');
    }
  }

  @override
  String toString() => pathTo;

  static Future<void> showList(List<SvgFile> files, {Progress progress}) async {
    progress ??= noOp;

    final paths = files.map((file) => file.pathTo).toList();

    final Process process =
        await Process.start('firefox', paths, mode: ProcessStartMode.normal);

    process.stdout.transform(utf8.decoder).listen((data) {
      progress(data);
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      progress(data);
    });
  }
}

final _empty = '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
 "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<!-- Generated by graphviz version 2.40.1 (20161225.0304)
 -->
<!-- Title: state transitions Pages: 1 -->
<svg width="8pt" height="8pt"
 viewBox="0.00 0.00 8.00 8.00" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<g id="graph0" class="graph" transform="scale(1 1) rotate(0) translate(4 4)">
<title>state transitions</title>
<polygon fill="#ffffff" stroke="transparent" points="-4,4 -4,-4 4,-4 4,4 -4,4"/>
</g>
</svg>
''';
