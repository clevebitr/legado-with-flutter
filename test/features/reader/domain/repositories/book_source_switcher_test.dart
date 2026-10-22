import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/repositories/book_source_switcher.dart';
import 'package:flutter_test/flutter_test.dart';

const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://a.test',
  bookUrl: 'https://a.test/book/0',
  name: '剑来',
  tocUrl: 'https://a.test/book/0',
);

void main() {
  group('ReaderSourceSwitch', () {
    test('ReaderSourceSwitch_givenValues_keepsThem', () {
      final ReaderSourceSwitch switched = _switched();

      expect(switched.book, _book);
      expect(switched.chapterIndex, 1);
    });
  });

  group('UnboundBookSourceSwitcher', () {
    test('candidates_whenNothingIsBound_answersAFailure', () async {
      // 端口没绑定时给可读的失败，而不是抛异常（platform.md §2 的习惯）。
      final ParseResult<List<ReaderSourceCandidate>> result =
          await const UnboundBookSourceSwitcher().candidates(_book);

      expect(
        (result as ParseFailure<List<ReaderSourceCandidate>>).kind,
        ParseFailureKind.unsupportedRule,
      );
      expect(result.rulePath, 'reader.changeSource');
    });

    test('switchTo_whenNothingIsBound_answersAFailure', () async {
      final ParseResult<ReaderSourceSwitch> result =
          await const UnboundBookSourceSwitcher().switchTo(
            book: _book,
            candidate: _candidate(),
            currentChapterName: '第一章',
            currentChapterIndex: 0,
          );

      expect(
        (result as ParseFailure<ReaderSourceSwitch>).kind,
        ParseFailureKind.unsupportedRule,
      );
    });
  });
}

/// A switch result built at **runtime**.
///
/// Constructed through a function so the `const` constructor actually executes: a `const` call is
/// folded at compile time, and the coverage report would then say the constructor never ran.
// ignore: prefer_const_constructors  — 见上：const 调用会被折叠，覆盖率就统计不到构造。
ReaderSourceSwitch _switched() => ReaderSourceSwitch(
  book: _book,
  chapterUrl: 'https://b.test/c/1',
  chapterName: '第二章',
  chapterIndex: 1,
);

/// A candidate built at runtime, for the same reason as [_switched].
// ignore: prefer_const_constructors
ReaderSourceCandidate _candidate() => ReaderSourceCandidate(
  sourceUrl: 'https://b.test',
  sourceName: 'b',
  bookUrl: 'https://b.test/book/1',
);
