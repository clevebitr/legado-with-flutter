// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_records_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The most recent reading sessions across every book (`docs/dev/roadmap.md` M19).
///
/// Read-only: records are appended by the reader on exit (ADR-0066 §决策 4), so there is no
/// mutation to expose here. The page groups the rows by day with the pure helper in
/// `domain/reading_record_days.dart` rather than asking the database for a second projection.

@ProviderFor(readingRecords)
final readingRecordsProvider = ReadingRecordsProvider._();

/// The most recent reading sessions across every book (`docs/dev/roadmap.md` M19).
///
/// Read-only: records are appended by the reader on exit (ADR-0066 §决策 4), so there is no
/// mutation to expose here. The page groups the rows by day with the pure helper in
/// `domain/reading_record_days.dart` rather than asking the database for a second projection.

final class ReadingRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReadingRecord>>,
          List<ReadingRecord>,
          FutureOr<List<ReadingRecord>>
        >
    with
        $FutureModifier<List<ReadingRecord>>,
        $FutureProvider<List<ReadingRecord>> {
  /// The most recent reading sessions across every book (`docs/dev/roadmap.md` M19).
  ///
  /// Read-only: records are appended by the reader on exit (ADR-0066 §决策 4), so there is no
  /// mutation to expose here. The page groups the rows by day with the pure helper in
  /// `domain/reading_record_days.dart` rather than asking the database for a second projection.
  ReadingRecordsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readingRecordsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readingRecordsHash();

  @$internal
  @override
  $FutureProviderElement<List<ReadingRecord>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ReadingRecord>> create(Ref ref) {
    return readingRecords(ref);
  }
}

String _$readingRecordsHash() => r'089ec2e42c3cbaed24c2bce2c16ac8dd6c9cef7f';
