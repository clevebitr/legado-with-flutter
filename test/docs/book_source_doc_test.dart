import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Doc-drift gates for `docs/dev/book-source.md` (S7 of the parity slices, ADR-0078).
///
/// These are the only tests in `test/` without a `lib/` counterpart: they compare what the
/// specification **claims** with what the code and the test suite actually contain, which is what
/// ADR-0012 asks for ("文档不能只由人看"). `docs/dev/testing.md` §3 records this one exception.
///
/// The two gates:
///
/// * **G1** — §11's rejection lists (the named `java.*` members and the Rhino interop packages) must
///   be identical to `__javaRejectedNames` / `__javaInteropNames` in the sandbox prelude;
/// * **G2** — every matrix row `book-source.md` §3 marks 已确认 must be named by at least one test
///   (`matrix #N`), so a row cannot keep claiming coverage after its test is gone.
const String _docPath = 'docs/dev/book-source.md';
const String _workerPath = 'lib/core/js/quickjs_worker.dart';
const String _testRoot = 'test';

/// The list `matrix #N` markers carry in a test name; the doc's rows are `1..31`.
final RegExp _matrixMarker = RegExp(r'matrix #(\d+)');

void main() {
  group('book-source.md', () {
    late String doc;
    late String worker;

    setUpAll(() {
      doc = File(_docPath).readAsStringSync();
      worker = File(_workerPath).readAsStringSync();
    });

    test('javaRejectedNames_givenTheSandboxAndTheDoc_listTheSameMembers', () {
      // G1：`__javaRejectedNames` 是「命中即抛可读错误」的名单，§11 抄了一份给人看；
      // 两边不一致就说明某一条状态变了而另一个地方没跟上（ADR-0012）。
      expect(
        _docNamesAfter(doc, '**这份名单是机器的对照面（S7 门禁 G1）：**', 0),
        _preludeList(worker, '__javaRejectedNames'),
      );
    });

    test('javaInteropNames_givenTheSandboxAndTheDoc_listTheSamePackages', () {
      expect(
        _docNamesAfter(doc, '- Rhino Java 互操作（`Packages.*` 与下列 `java.*` 包', 0),
        _preludeList(worker, '__javaInteropNames'),
      );
    });

    test('matrix_givenEveryConfirmedRow_isNamedByATest', () {
      // G2：矩阵的「已确认」行必须有具名用例（`matrix #N`）。行号变了、或用例被删了，这里先红。
      final Set<int> covered = _coveredMatrixRows();
      final List<int> missing = <int>[
        for (final int row in _confirmedMatrixRows(doc))
          if (!covered.contains(row)) row,
      ];

      expect(
        missing,
        isEmpty,
        reason:
            'These matrix rows claim 已确认 but no test names them: '
            '${missing.join(', ')}',
      );
    });
  });
}

/// The names of the first fenced `text` block whose preceding line contains [marker].
///
/// [offset] selects which such block to read when one marker guards several: the doc keeps the
/// sandbox lists as `text` blocks, one name per line.
List<String> _docNamesAfter(String doc, String marker, int offset) {
  final List<String> lines = doc.split('\n');
  var seen = 0;
  for (var index = 0; index < lines.length; index++) {
    if (!lines[index].contains(marker)) {
      continue;
    }
    // 标记行之后的第一个 ```text 块；块内一行一个名字，空行与注释忽略。
    var cursor = index + 1;
    while (cursor < lines.length &&
        !lines[cursor].trim().startsWith('```text')) {
      cursor++;
    }
    if (cursor >= lines.length) {
      break;
    }
    if (seen++ < offset) {
      index = cursor;
      continue;
    }
    final List<String> names = <String>[];
    for (cursor += 1; cursor < lines.length; cursor++) {
      final String line = lines[cursor].trim();
      if (line == '```') {
        break;
      }
      if (line.isNotEmpty) {
        names.add(line);
      }
    }

    return names;
  }

  fail('No `text` block follows the marker in $_docPath: $marker');
}

/// The string entries of the JavaScript array literal [name] in the sandbox prelude.
///
/// The prelude is a raw Dart string, so the list is read from the literal instead of being exported
/// twice: the gate has to see the **same text** the worker runs.
List<String> _preludeList(String worker, String name) {
  final int start = worker.indexOf('__${name}_placeholder');
  final int assignment = worker.indexOf(start < 0 ? '$name = [' : '$name = [');
  if (assignment < 0) {
    fail('The sandbox prelude has no `$name` array literal.');
  }
  final int end = worker.indexOf(']', assignment);
  final String literal = worker.substring(assignment, end);

  return <String>[
    for (final RegExpMatch match in RegExp(
      "'([A-Za-z0-9]+)'",
    ).allMatches(literal))
      match.group(1) ?? '',
  ];
}

/// The matrix row numbers `book-source.md` §3 marks 已确认.
///
/// The table is markdown, and its cells carry escaped pipes (`\|`) inside examples, so the split is
/// on **unescaped** pipes only. The last cell of a row is the status.
List<int> _confirmedMatrixRows(String doc) {
  final List<int> rows = <int>[];
  for (final String line in doc.split('\n')) {
    final List<String> cells = _cellsOf(line);
    if (cells.length < 6) {
      continue;
    }
    final int? number = int.tryParse(cells.first);
    if (number == null) {
      continue;
    }
    if (cells.last.startsWith('已确认')) {
      rows.add(number);
    }
  }

  return rows..sort();
}

/// Splits one markdown table row into its cells, honouring `\|`.
List<String> _cellsOf(String line) {
  final String trimmed = line.trim();
  if (!trimmed.startsWith('|')) {
    return const <String>[];
  }
  final List<String> cells = <String>[];
  final StringBuffer current = StringBuffer();
  for (var index = 1; index < trimmed.length; index++) {
    final String character = trimmed[index];
    if (character == r'\' && index + 1 < trimmed.length) {
      current.write(trimmed[++index]);
      continue;
    }
    if (character == '|') {
      cells.add(current.toString().trim());
      current.clear();
      continue;
    }
    current.write(character);
  }
  // 行尾的 `|` 之后没有内容：最后一个 cell 是空的，丢掉它。
  if (current.isNotEmpty) {
    cells.add(current.toString().trim());
  }

  return cells;
}

/// Every `matrix #N` an existing test names.
Set<int> _coveredMatrixRows() {
  final Set<int> covered = <int>{};
  for (final FileSystemEntity entity in Directory(
    _testRoot,
  ).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('_test.dart')) {
      continue;
    }
    for (final RegExpMatch match in _matrixMarker.allMatches(
      entity.readAsStringSync(),
    )) {
      final int? row = int.tryParse(match.group(1) ?? '');
      if (row != null) {
        covered.add(row);
      }
    }
  }

  return covered;
}
