// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Reader';

  @override
  String get bookSourceListTitle => 'Book sources';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionImport => 'Import';

  @override
  String get bookSourceSearchTitle => 'Search';

  @override
  String get bookSourceSearchHint => 'Title or author';

  @override
  String get bookSourceSearchAction => 'Search';

  @override
  String get bookSourceSearchPrompt =>
      'Enter a keyword to search the book source.';

  @override
  String get bookSourceSearchEmpty => 'No book matched this keyword.';

  @override
  String get bookSourceMissingSource =>
      'No book source is stored yet. Import one to start reading.';

  @override
  String get bookSourceDetailTitle => 'Book details';

  @override
  String get bookSourceTocTitle => 'Chapters';

  @override
  String get bookSourceReaderTitle => 'Text';

  @override
  String bookSourceAuthorLine(String author) {
    return 'Author: $author';
  }

  @override
  String bookSourceKindLine(String kind) {
    return 'Category: $kind';
  }

  @override
  String bookSourceLastChapterLine(String chapter) {
    return 'Latest chapter: $chapter';
  }

  @override
  String get failureNetworkTimeout =>
      'Request timed out. Please try again later.';

  @override
  String get failureNetworkFailed =>
      'Connection failed. Check your network and try again.';

  @override
  String get failureNetworkForbidden =>
      'The site refused access (403). The book source may need an update.';

  @override
  String get failureNotFound =>
      'The requested page was not found (404). The book source may be broken.';

  @override
  String get failureEncodingFailed =>
      'The page encoding could not be detected.';

  @override
  String get failureParseFailed =>
      'Parsing failed. The book source rules may be out of date.';

  @override
  String get failureInvalidBookSource =>
      'This file is not a valid book source.';

  @override
  String get legalNoticesTitle => 'Legal notices';

  @override
  String get legalNoticesCopyright =>
      'flutter_reader, Copyright (C) 2026 Clevebitr.';

  @override
  String get legalNoticesNoWarranty =>
      'This program comes with ABSOLUTELY NO WARRANTY. It is free software licensed under the GNU GPL-3.0, and you are welcome to redistribute it under certain conditions.';

  @override
  String get legalNoticesViewLicense => 'View the full license';

  @override
  String get legalNoticesCorrespondingSource => 'Corresponding source code';

  @override
  String get legalNoticesProhibitedUse =>
      'Do not use this app to infringe copyright. Scraping, aggregating or redistributing unauthorised content through book sources is prohibited, and anyone doing so bears the full legal responsibility.';

  @override
  String get failureUnsupportedRule =>
      'This book source uses a rule type that is not supported yet.';

  @override
  String get bookSourceExploreTitle => 'Discover';

  @override
  String get bookSourceExploreAction => 'Discover page';

  @override
  String get bookSourceExplorePrompt => 'Pick a category to start browsing';

  @override
  String get bookSourceExploreEmpty =>
      'This book source has no discover categories';

  @override
  String get bookSourceExploreEmptyCategory => 'This category has no books.';

  @override
  String bookSourceImportSucceeded(int count) {
    return 'Imported $count book sources.';
  }

  @override
  String bookSourceImportPartiallySkipped(int count, int skipped) {
    return 'Imported $count book sources; $skipped entries were skipped as invalid.';
  }

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get bookSourceMissingSourceAction => 'Manage book sources';

  @override
  String get bookSourceListEmpty => 'No book source is stored yet.';

  @override
  String get bookSourceListLoadFailed =>
      'The stored book sources could not be read.';

  @override
  String get bookSourceCurrentLabel => 'Current book source';

  @override
  String get bookSourceVariantLabel => 'Same site, another rule set';

  @override
  String get bookSourceListDeleteTitle => 'Delete this book source?';

  @override
  String bookSourceListDeleteBody(String name) {
    return '$name and its stored rules will be removed.';
  }

  @override
  String get bookSourceImportTitle => 'Import book sources';

  @override
  String get bookSourceImportTextLabel => 'Book source JSON';

  @override
  String get bookSourceImportTextHint =>
      'Paste an exported book source file here';

  @override
  String get bookSourceImportUrlLabel => 'Or a URL';

  @override
  String get bookSourceImportUrlHint => 'https://example.com/sources.json';

  @override
  String get bookSourceImportFileAction => 'Choose a JSON file';

  @override
  String get shelfTitle => 'Bookshelf';

  @override
  String get shelfEmpty =>
      'Your shelf is empty. Open a book\'s details and choose “Add to shelf”.';

  @override
  String get shelfLoadFailed => 'The shelf could not be loaded.';

  @override
  String get shelfStatusTracking => 'Reading';

  @override
  String get shelfStatusRead => 'Finished';

  @override
  String get shelfActionPin => 'Pin to top';

  @override
  String get shelfActionUnpin => 'Unpin';

  @override
  String get shelfActionMarkRead => 'Mark as finished';

  @override
  String get shelfActionMarkTracking => 'Mark as reading';

  @override
  String get shelfActionRemove => 'Remove from shelf';

  @override
  String get shelfRemoveTitle => 'Remove this book?';

  @override
  String get shelfRemoveBody => 'Its reading progress is removed too.';

  @override
  String shelfProgressLine(String chapter) {
    return 'Reading: $chapter';
  }

  @override
  String get shelfAddAction => 'Add to shelf';

  @override
  String get shelfAddSucceeded => 'Added to the shelf.';

  @override
  String get shelfAddFailed => 'The book could not be added to the shelf.';

  @override
  String get shelfWriteFailed => 'The shelf could not be updated.';

  @override
  String get actionDecrease => 'Decrease';

  @override
  String get actionIncrease => 'Increase';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLoadFailed => 'The settings could not be loaded.';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get settingsThemeSystem => 'Follow system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsFontScale => 'Text size';

  @override
  String settingsFontScaleValue(int percent) {
    return '$percent%';
  }

  @override
  String get settingsConcurrency => 'Concurrent requests per source';

  @override
  String get settingsConcurrencyHint =>
      '1 to 8. Higher values are faster and less polite to the site.';

  @override
  String get settingsCache => 'Cache';

  @override
  String get settingsClearCache => 'Clear cache';

  @override
  String get settingsClearCacheTitle => 'Clear the whole cache?';

  @override
  String get settingsClearCacheBody =>
      'Cached pages and chapter bodies are downloaded again when needed.';

  @override
  String settingsCacheCleared(int count) {
    return 'Removed $count cached entries.';
  }

  @override
  String get bookSourceCheckTitle => 'Check book sources';

  @override
  String get bookSourceCheckIntro =>
      'Each source runs through search, discover, details, chapters and body.';

  @override
  String get bookSourceCheckStages => 'Stages';

  @override
  String get bookSourceCheckStageSearch => 'Search';

  @override
  String get bookSourceCheckStageExplore => 'Discover';

  @override
  String get bookSourceCheckStageInfo => 'Details';

  @override
  String get bookSourceCheckStageToc => 'Chapters';

  @override
  String get bookSourceCheckStageContent => 'Body';

  @override
  String get bookSourceCheckKeyword => 'Keyword';

  @override
  String get bookSourceCheckKeywordHint =>
      'Keyword sent to every checked source';

  @override
  String get bookSourceCheckTimeout => 'Timeout per source';

  @override
  String get bookSourceCheckStart => 'Start check';

  @override
  String get bookSourceCheckStop => 'Stop';

  @override
  String get bookSourceCheckEmpty =>
      'No book source is stored yet. Import one to check it.';

  @override
  String get bookSourceCheckSelectionEmpty =>
      'Select at least one book source.';

  @override
  String get bookSourceCheckStatusPending => 'Waiting';

  @override
  String get bookSourceCheckStatusRunning => 'Checking';

  @override
  String get bookSourceCheckStatusSucceeded => 'Passed';

  @override
  String get bookSourceCheckStatusFailed => 'Failed';

  @override
  String get bookSourceCheckStatusCancelled => 'Cancelled';

  @override
  String get bookSourceCheckFailureCheckFailed => 'The check found problems.';

  @override
  String get bookSourceCheckFailureSourceMissing =>
      'The source was deleted meanwhile.';

  @override
  String get bookSourceCheckFailureSaveFailed =>
      'The result could not be saved.';

  @override
  String bookSourceCheckFailedAt(String rulePath) {
    return 'Failed at $rulePath';
  }

  @override
  String bookSourceCheckElapsed(int millis) {
    return 'Took $millis ms';
  }

  @override
  String get bookSourceCheckOpenDebug => 'Debug this source';

  @override
  String get bookSourceCheckSelectAll => 'Select all';

  @override
  String get bookSourceCheckSelectNone => 'Select none';

  @override
  String get bookSourceDebugTitle => 'Debug a book source';

  @override
  String get bookSourceDebugTarget => 'Target';

  @override
  String get bookSourceDebugTargetSearch => 'Search';

  @override
  String get bookSourceDebugTargetExplore => 'Discover';

  @override
  String get bookSourceDebugTargetInfo => 'Details';

  @override
  String get bookSourceDebugTargetToc => 'Chapters';

  @override
  String get bookSourceDebugTargetContent => 'Body';

  @override
  String get bookSourceDebugQuery => 'Query';

  @override
  String get bookSourceDebugQueryKeywordHint => 'Keyword to search for';

  @override
  String get bookSourceDebugQueryUrlHint => 'Page URL';

  @override
  String get bookSourceDebugExamples => 'Examples';

  @override
  String get bookSourceDebugStart => 'Run';

  @override
  String get bookSourceDebugStop => 'Stop';

  @override
  String get bookSourceDebugClear => 'Clear';

  @override
  String get bookSourceDebugEmpty =>
      'No event yet. Run a target to see the chain.';

  @override
  String get bookSourceDebugStatusRunning => 'Running';

  @override
  String get bookSourceDebugStatusSucceeded => 'Done';

  @override
  String get bookSourceDebugStatusFailed => 'Failed';

  @override
  String get bookSourceDebugStatusCancelled => 'Cancelled';

  @override
  String get bookSourceDebugEventMessage => 'Message';

  @override
  String get bookSourceDebugEventSource => 'Source';

  @override
  String get bookSourceDebugEventError => 'Error';

  @override
  String get bookSourceDebugMissingSource =>
      'Choose a book source on the source list first.';

  @override
  String get bookSourceDebugStatusIdle => 'Not run yet';

  @override
  String get readerTocAction => 'Chapters';

  @override
  String get readerSettingsAction => 'Reading settings';

  @override
  String get readerFontSize => 'Text size';

  @override
  String get readerLineHeight => 'Line spacing';

  @override
  String get readerBackground => 'Background';

  @override
  String get readerBackgroundSystem => 'Theme';

  @override
  String get readerBackgroundPaper => 'Paper';

  @override
  String get readerBackgroundSepia => 'Sepia';

  @override
  String get readerBackgroundDark => 'Dark';

  @override
  String get readerPageMode => 'Turn pages';

  @override
  String get readerPageModeScroll => 'Scroll';

  @override
  String get readerPageModePaged => 'Pages';

  @override
  String get readerPreviousChapter => 'Previous chapter';

  @override
  String get readerNextChapter => 'Next chapter';

  @override
  String get readerChapterEnd => 'End of this chapter';

  @override
  String get readerLastChapter => 'This is the last chapter';

  @override
  String get readerNoChapter => 'This book has no readable chapter.';

  @override
  String bookSourceUpdateTimeLine(String value) {
    return 'Updated: $value';
  }

  @override
  String get bookSourceListSortLabel => 'Sort by';

  @override
  String get bookSourceListSortDefault => 'Manual order';

  @override
  String get bookSourceListSortWeight => 'Weight';

  @override
  String get bookSourceListSortRespondTime => 'Response time';

  @override
  String get bookSourceListSortName => 'Name';

  @override
  String get bookSourceListGroupAll => 'All groups';

  @override
  String bookSourceListRespondTimeLine(int millis) {
    return '$millis ms';
  }

  @override
  String get bookSourceListCommentTitle => 'Check note';

  @override
  String get bookSourceListCommentAction => 'View note';

  @override
  String get bookSourceListNoMatch => 'No source matches this group.';

  @override
  String get searchScopeLabel => 'Search in';

  @override
  String get searchScopeAll => 'All enabled sources';

  @override
  String get searchScopeNamed => 'Chosen sources';

  @override
  String get searchFilterLabel => 'Filters';

  @override
  String get searchTypeLabel => 'Source types';

  @override
  String get searchTypeText => 'Text';

  @override
  String get searchTypeAudio => 'Audio';

  @override
  String get searchTypeImage => 'Image';

  @override
  String get searchTypeFile => 'File';

  @override
  String get searchMatchLabel => 'Match';

  @override
  String get searchMatchDefault => 'Fuzzy';

  @override
  String get searchMatchExact => 'Exact name or author';

  @override
  String searchProgress(int done, int total) {
    return '$done/$total sources';
  }

  @override
  String searchPartialFailed(int failed) {
    return '$failed sources failed';
  }

  @override
  String get searchPause => 'Pause';

  @override
  String get searchResume => 'Resume';

  @override
  String get searchStop => 'Stop';

  @override
  String get searchLoadMore => 'Load more';

  @override
  String searchOriginsLine(int count) {
    return '$count sources';
  }

  @override
  String get searchNoSources => 'No source can be searched in this scope.';

  @override
  String get searchTypeVideo => 'Video';

  @override
  String get bookSourceStartReading => 'Start reading';

  @override
  String get bookSourceContinueReading => 'Continue reading';

  @override
  String get bookSourceIntroExpand => 'Show more';

  @override
  String get bookSourceIntroCollapse => 'Show less';

  @override
  String get bookSourceListSearchHint => 'Search name, URL or group';

  @override
  String get bookSourceListSelectAll => 'Select all';

  @override
  String get bookSourceListInvertSelection => 'Invert';

  @override
  String bookSourceListSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get bookSourceListBatchEnable => 'Enable';

  @override
  String get bookSourceListBatchDisable => 'Disable';

  @override
  String get bookSourceListBatchDelete => 'Delete';

  @override
  String bookSourceListBatchDeleteTitle(int count) {
    return 'Delete $count sources?';
  }

  @override
  String get bookSourceListBatchDeleteBody =>
      'Books you added from them stay on the shelf.';

  @override
  String get bookSourceListBatchGroup => 'Group';

  @override
  String get bookSourceListGroupNone => 'No group';

  @override
  String get bookSourceListGroupNew => 'New group…';

  @override
  String get bookSourceListGroupNameHint => 'Group name';

  @override
  String get bookSourceCheckFilterLabel => 'Check status';

  @override
  String get bookSourceCheckFilterAll => 'All';

  @override
  String get bookSourceCheckFilterHealthy => 'Healthy';

  @override
  String get bookSourceCheckFilterFailing => 'Has failures';

  @override
  String get bookSourceRowCheck => 'Check this source';

  @override
  String get bookSourceRowEdit => 'Edit';

  @override
  String get bookSourceRowExport => 'Export';

  @override
  String get bookSourceCheckPassed => 'Check passed';

  @override
  String bookSourceCheckFound(String groups) {
    return 'Check found: $groups';
  }

  @override
  String get bookSourceExportCopied => 'Source JSON copied';

  @override
  String get bookSourceExportSaved => 'Saved';

  @override
  String get bookSourceExportFailed => 'Could not export this source';

  @override
  String get bookSourceEditTitle => 'Edit source';

  @override
  String get bookSourceEditSaved => 'Saved';

  @override
  String get bookSourceEditInvalidFields => 'Fix the highlighted fields first';

  @override
  String get bookSourceEditIdentityConflict =>
      'Another source already has exactly these rules';

  @override
  String get bookSourceEditUrlHint =>
      'Changing the URL is like switching source: the shelf keeps the old one.';

  @override
  String get bookSourceFieldName => 'Name';

  @override
  String get bookSourceFieldUrl => 'Source URL';

  @override
  String get bookSourceFieldGroup => 'Group';

  @override
  String get bookSourceFieldType => 'Type';

  @override
  String get bookSourceFieldWeight => 'Weight';

  @override
  String get bookSourceFieldHeader => 'Header (JSON)';

  @override
  String get bookSourceFieldSearchRule => 'Search rule';

  @override
  String get bookSourceFieldBookInfoRule => 'Book info rule';

  @override
  String get bookSourceFieldTocRule => 'Chapters rule';

  @override
  String get bookSourceFieldContentRule => 'Content rule';

  @override
  String get actionSave => 'Save';

  @override
  String get bookSourceRowCheckRunning => 'Checking…';

  @override
  String get readerFontFamily => 'Font';

  @override
  String get readerFontFamilyTheme => 'Theme default';

  @override
  String get readerFontFamilySerif => 'Serif';

  @override
  String get readerFontFamilySans => 'Sans-serif';

  @override
  String get readerFontFamilyMono => 'Monospace';

  @override
  String get readerParagraphSpacing => 'Paragraph spacing';

  @override
  String get readerFirstLineIndent => 'First-line indent';

  @override
  String get readerPagePadding => 'Page margin';

  @override
  String get readerPaddingNarrow => 'Narrow';

  @override
  String get readerPaddingMedium => 'Medium';

  @override
  String get readerPaddingWide => 'Wide';

  @override
  String readerChapterProgress(int current, int total) {
    return '$current/$total chapters';
  }

  @override
  String readerChapterPercent(int percent) {
    return '$percent%';
  }

  @override
  String get readerChangeSource => 'Change source';

  @override
  String get readerBrightness => 'Brightness';

  @override
  String get readerTocSort => 'Reversed';

  @override
  String get readerTocSearchHint => 'Search chapters';

  @override
  String get readerSourceTitle => 'Change source';

  @override
  String get readerSourceEmpty => 'No other source has this book.';

  @override
  String get readerSourceSearching => 'Searching other sources…';

  @override
  String readerSourceChapters(int count) {
    return '$count chapters';
  }

  @override
  String get readerSourceFailed => 'Could not switch source';

  @override
  String readerSourceAligned(String chapter) {
    return 'Aligned to: $chapter';
  }
}
