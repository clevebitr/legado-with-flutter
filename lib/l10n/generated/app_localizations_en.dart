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
  String get shellTabBookshelf => 'Shelf';

  @override
  String get shellTabExplore => 'Discover';

  @override
  String get shellTabSearch => 'Search';

  @override
  String get shellTabMy => 'Me';

  @override
  String get myTitle => 'Me';

  @override
  String get mySectionContent => 'Content';

  @override
  String get mySectionApp => 'App';

  @override
  String get myBookSources => 'Book sources';

  @override
  String get myBookSourcesBody => 'Import, check and group';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutLicenses => 'Licenses and legal notices';

  @override
  String get aboutSourceCode => 'Source code';

  @override
  String get aboutCopySource => 'Copy address';

  @override
  String get aboutCopied => 'Copied';

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
  String get legalNoticesLicenseTitle => 'GNU GPL-3.0';

  @override
  String get legalNoticesLicenseFailed =>
      'The license text could not be loaded. Reopen this page to try again.';

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
  String bookSourceImportPreviewSummary(
    int newCount,
    int refreshCount,
    int rejected,
  ) {
    return '$newCount new · $refreshCount to refresh · $rejected rejected';
  }

  @override
  String get bookSourceImportEntryNew => 'New';

  @override
  String get bookSourceImportEntryRefresh => 'Already imported · will refresh';

  @override
  String bookSourceImportEntryUnknown(int index) {
    return 'Entry $index';
  }

  @override
  String get bookSourceImportRejectionMissingUrl => 'Missing bookSourceUrl';

  @override
  String get bookSourceImportRejectionMissingName => 'Missing bookSourceName';

  @override
  String get bookSourceImportRejectionUnreadable =>
      'This entry cannot be read as a book source';

  @override
  String get bookSourceImportRejectionNotAnObject => 'Not a JSON object';

  @override
  String bookSourceImportCommit(int count) {
    return 'Import selected ($count)';
  }

  @override
  String get bookSourceImportSelectAll => 'Select all';

  @override
  String get bookSourceImportDeselectAll => 'Deselect all';

  @override
  String get bookSourceImportBack => 'Back to the form';

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
  String mangaPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get mangaImageFailed => 'This page failed to load.';

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
  String get searchScopeFellBack =>
      'That scope no longer exists, so every enabled source was searched.';

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
  String get bookSourceListSelectMode => 'Select sources';

  @override
  String get bookSourceListInvalidDisable => 'Disable failing';

  @override
  String get bookSourceListInvalidDelete => 'Delete failing';

  @override
  String bookSourceListInvalidDisabled(int count) {
    return 'Disabled $count failing sources';
  }

  @override
  String bookSourceListInvalidDeleteTitle(int count) {
    return 'Delete $count failing sources?';
  }

  @override
  String get bookSourceListGroupSelectSources =>
      'Select every source in this group';

  @override
  String get bookSourceListGroupDeleteSources =>
      'Delete every source in this group';

  @override
  String bookSourceListGroupDeleteSourcesTitle(int count, String group) {
    return 'Delete the $count sources in “$group”?';
  }

  @override
  String bookSourceListSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get bookSourceListBatchCheck => 'Check selected';

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
  String get bookSourceCheckStatusPassed => 'Check passed';

  @override
  String get bookSourceCheckStatusDegraded => 'Timed out or JS failed';

  @override
  String get bookSourceCheckStatusUnchecked => 'Never checked';

  @override
  String get bookSourceListLastCheckJustNow => 'Checked just now';

  @override
  String bookSourceListLastCheckMinutesAgo(int count) {
    return 'Checked $count min ago';
  }

  @override
  String bookSourceListLastCheckHoursAgo(int count) {
    return 'Checked $count h ago';
  }

  @override
  String bookSourceListLastCheckDaysAgo(int count) {
    return 'Checked $count d ago';
  }

  @override
  String bookSourceListLastCheckOn(String date) {
    return 'Checked $date';
  }

  @override
  String bookSourceListLastCheckLine(String when, int millis) {
    return '$when · $millis ms';
  }

  @override
  String get bookSourceListBatchMoveTop => 'Move to top';

  @override
  String get bookSourceListBatchMoveBottom => 'Move to bottom';

  @override
  String get bookSourceListBatchRemoveGroup => 'Remove from group';

  @override
  String get bookSourceListExploreOn => 'Discover on';

  @override
  String get bookSourceListExploreOff => 'Discover off';

  @override
  String get bookSourceExploreDisabled =>
      'Discover is turned off for this source. Turn it back on in the source list.';

  @override
  String get bookSourceRowExploreEnable => 'Turn discover on';

  @override
  String get bookSourceRowExploreDisable => 'Turn discover off';

  @override
  String get bookSourceListSortAscending => 'Ascending';

  @override
  String get bookSourceListSortDescending => 'Descending';

  @override
  String get bookSourceListGroupByDomain => 'Group by domain';

  @override
  String get bookSourceListViewOptions => 'View';

  @override
  String get bookSourceListMoreActions => 'More actions';

  @override
  String get bookSourceListGroupManage => 'Manage groups';

  @override
  String get bookSourceListGroupRename => 'Rename group';

  @override
  String get bookSourceListGroupDelete => 'Delete group';

  @override
  String bookSourceListGroupDeleteBody(String group) {
    return 'Every source leaves “$group”; the sources themselves stay.';
  }

  @override
  String bookSourceListGroupRemoveFrom(String group) {
    return 'Remove from “$group”';
  }

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

  @override
  String get readerTtsAction => 'Read aloud';

  @override
  String get readerTtsTitle => 'Read aloud';

  @override
  String get readerTtsStart => 'Start reading';

  @override
  String get readerTtsPause => 'Pause';

  @override
  String get readerTtsResume => 'Resume';

  @override
  String get readerTtsStop => 'Stop';

  @override
  String get readerTtsRate => 'Speed';

  @override
  String get readerTtsPitch => 'Pitch';

  @override
  String get readerTtsVoice => 'Voice';

  @override
  String readerTtsVoiceLabel(String name, String locale) {
    return '$name ($locale)';
  }

  @override
  String get readerTtsSystemVoice => 'System default';

  @override
  String get readerTtsKeepOnExit => 'Keep reading after leaving the reader';

  @override
  String get readerTtsFailed =>
      'The system speech engine could not read this chapter.';

  @override
  String get readerAudioFailed => 'This track could not be played.';

  @override
  String get readerAudioPlay => 'Play';

  @override
  String get readerAudioPause => 'Pause';

  @override
  String get readerAudioReplay => 'Play again';

  @override
  String get readerAudioSpeed => 'Speed';

  @override
  String readerAudioSpeedValue(String speed) {
    return '$speed×';
  }

  @override
  String readerAudioTrackCount(int index, int total) {
    return 'Part $index of $total';
  }

  @override
  String get settingsNetwork => 'Network';

  @override
  String get settingsPlainHttp => 'Allow plaintext HTTP';

  @override
  String get settingsPlainHttpHint =>
      'Some book sources and audio streams only provide http:// addresses. Page requests follow this switch too.';

  @override
  String get readerAudioPlainHttp =>
      'This track uses plaintext HTTP. Turn on “Allow plaintext HTTP” in settings to play it.';

  @override
  String get bookSourceRowSignIn => 'Sign in / pass check';

  @override
  String get bookSourceSignInDone =>
      'The site\'s cookies are saved; the source can be checked again.';

  @override
  String get bookSourceSignInFailed =>
      'The sign-in / verification did not finish.';

  @override
  String get bookSourceSignInUnsupported =>
      'This platform has no WebView; finish the check in the system browser first.';

  @override
  String get bookmarkTitle => 'Bookmarks';

  @override
  String get bookmarkEmpty =>
      'No bookmarks yet. Tap the bookmark button in the reader toolbar to mark your place.';

  @override
  String get bookmarkLoadFailed => 'Bookmarks could not be loaded.';

  @override
  String get bookmarkAdd => 'Add bookmark';

  @override
  String get bookmarkRemove => 'Remove bookmark';

  @override
  String get bookmarkAdded => 'Bookmark added';

  @override
  String get bookmarkRemoved => 'Bookmark removed';

  @override
  String get bookmarkFailed => 'The bookmark could not be saved.';

  @override
  String get bookmarkDeleteAction => 'Delete bookmark';

  @override
  String get bookSourceReadingRecords => 'Reading records';

  @override
  String get readingRecordsTitle => 'Reading records';

  @override
  String get readingRecordsEmpty =>
      'No reading records yet. Sessions shorter than a minute are not recorded.';

  @override
  String get readingRecordsLoadFailed => 'Reading records could not be loaded.';

  @override
  String bookReadingRecordsTitle(String book) {
    return 'Reading records · $book';
  }

  @override
  String get bookReadingRecordsEmpty => 'This book has no reading records yet.';

  @override
  String readingRecordMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String readingRecordHours(int hours) {
    return '$hours h';
  }

  @override
  String readingRecordHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get myBookmarks => 'Bookmarks';

  @override
  String get myBookmarksBody => 'Every position you marked';

  @override
  String get myReadingRecords => 'Reading records';

  @override
  String get myReadingRecordsBody => 'What you read, by day';

  @override
  String get shelfManageGroups => 'Manage groups';

  @override
  String get shelfGroupAll => 'All';

  @override
  String get shelfGroupUngrouped => 'Ungrouped';

  @override
  String get shelfGroupEmpty => 'No books in this group yet.';

  @override
  String get shelfGroupsTitle => 'Groups';

  @override
  String get shelfGroupsEmpty =>
      'No groups yet. Create one with the button below.';

  @override
  String get shelfGroupCreate => 'New group';

  @override
  String get shelfGroupCreateAction => 'Create';

  @override
  String get shelfGroupNameHint => 'Group name';

  @override
  String get shelfGroupRename => 'Rename';

  @override
  String get shelfGroupRenameTitle => 'Rename group';

  @override
  String get shelfGroupDelete => 'Delete group';

  @override
  String get shelfGroupDeleteTitle => 'Delete group';

  @override
  String get shelfGroupDeleteBody =>
      'The books go back to ungrouped and are not deleted.';

  @override
  String get shelfGroupNameTaken => 'A group with this name already exists.';

  @override
  String get shelfSelectionExit => 'Exit selection';

  @override
  String shelfSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get shelfSelectionClear => 'Clear selection';

  @override
  String get shelfSelectAll => 'Select all';

  @override
  String get shelfBatchAction => 'Batch actions';

  @override
  String get shelfBatchGroup => 'Move to group';

  @override
  String get bookSourceShelfGroup => 'Move to group';

  @override
  String get bookSourceShelfGroupHint =>
      'Add the book to the shelf before grouping it.';

  @override
  String get bookSourceChangeCover => 'Change cover';

  @override
  String get bookSourceResetCover => 'Reset cover';

  @override
  String get bookSourceBookCache => 'Book cache';

  @override
  String bookSourceBookCacheCount(int count) {
    return '$count chapters cached';
  }

  @override
  String get bookSourceBookCacheClear => 'Clear this book\'s cache';

  @override
  String bookSourceBookCacheCleared(int count) {
    return 'Cleared $count cached items';
  }

  @override
  String get bookSourceBookCacheFailed => 'The cache action failed.';

  @override
  String sourceVerificationTitle(String title, String source) {
    return '$title · $source';
  }

  @override
  String get sourceVerificationDone => 'Done';

  @override
  String get sourceVerificationFailed => 'Verification was not completed.';

  @override
  String sourceCaptchaTitle(String source) {
    return 'Captcha · $source';
  }

  @override
  String get sourceCaptchaImage => 'Captcha image';

  @override
  String get sourceCaptchaHint => 'Type the characters in the image';

  @override
  String get sourceCaptchaConfirm => 'Confirm';

  @override
  String get failureLoginRequired =>
      'This source needs a sign-in or a fresh human check; open the source and finish it first.';

  @override
  String get mySectionRules => 'Rules';

  @override
  String get rulesReplaceTitle => 'Replace & clean';

  @override
  String get rulesTocTitle => 'Chapter rules';

  @override
  String get rulesDictTitle => 'Dictionaries';

  @override
  String get rulesHighlightTitle => 'Highlight tags';

  @override
  String get rulesAdd => 'Add rule';

  @override
  String get rulesEditTitle => 'Edit rule';

  @override
  String get rulesEmpty => 'No rules yet';

  @override
  String get rulesLoadFailed => 'The rules could not be loaded.';

  @override
  String get rulesGone => 'This rule no longer exists.';

  @override
  String get rulesBroken => 'Unreadable rule';

  @override
  String get rulesBuiltIn => 'Built-in';

  @override
  String get rulesBrokenNotice =>
      'This rule\'s stored content cannot be read. It is shown below; saving replaces it.';

  @override
  String get rulesReorderHandle => 'Reorder';

  @override
  String get rulesNameLabel => 'Name';

  @override
  String get rulesPatternLabel => 'Find (regular expression or text)';

  @override
  String get rulesReplacementLabel => 'Replace with';

  @override
  String get rulesIsRegexLabel => 'Use a regular expression';

  @override
  String get rulesRuleLabel => 'Chapter title rule';

  @override
  String get rulesSerialNumberLabel => 'Serial number (optional)';

  @override
  String get rulesUrlRuleLabel => 'Lookup address';

  @override
  String get rulesShowRuleLabel => 'Extract rule';

  @override
  String get rulesColorLabel => 'Colour, #AARRGGBB (optional)';

  @override
  String get rulesGroupLabel => 'Group (optional)';

  @override
  String get rulesEnabledLabel => 'Enabled';

  @override
  String get rulesRequired => 'Required.';

  @override
  String get rulesInvalidRegex => 'This is not a valid regular expression.';

  @override
  String get rulesInvalidColor => 'Use #RRGGBB or #AARRGGBB.';

  @override
  String get readerSearchAction => 'Search in book';

  @override
  String get readerSearchHint => 'Search this book';

  @override
  String get readerSearchStart => 'Search';

  @override
  String get readerSearchStop => 'Stop';

  @override
  String readerSearchProgress(int scanned, int total) {
    return 'Searched $scanned of $total chapters';
  }

  @override
  String readerSearchStopped(int scanned, int total) {
    return 'Stopped after $scanned of $total chapters.';
  }

  @override
  String readerSearchBudgetSpent(int scanned, int total) {
    return 'Time is up: stopped after $scanned of $total chapters.';
  }

  @override
  String get readerSearchEmpty => 'Nothing found.';

  @override
  String readerSearchFailedChapters(int count) {
    return '$count chapters could not be read.';
  }

  @override
  String get readerSearchUntitledChapter => 'Untitled chapter';

  @override
  String get rulesImportTitle => 'Import rules';

  @override
  String get rulesImportTextLabel => 'Rules JSON';

  @override
  String get rulesImportTextHint => 'Paste the contents of a 净化规则 JSON file';

  @override
  String get rulesImportUrlLabel => 'Or a URL';

  @override
  String get rulesImportUrlHint => 'https://…/replaceRules.json';

  @override
  String get rulesImportFileAction => 'Choose a JSON file';

  @override
  String get rulesImportSelectAll => 'Import all of them';

  @override
  String rulesImportSelected(int selected, int usable) {
    return '$selected of $usable selected';
  }

  @override
  String rulesImportCommit(int count) {
    return 'Import selected ($count)';
  }

  @override
  String rulesImportSucceeded(int created, int updated) {
    return 'Imported $created new rules and updated $updated.';
  }

  @override
  String rulesImportSucceededWithSkipped(
    int created,
    int updated,
    int skipped,
  ) {
    return 'Imported $created new rules and updated $updated; $skipped entries were skipped as unreadable.';
  }

  @override
  String get rulesImportUntitled => 'Untitled rule';

  @override
  String get rulesImportUpdate => 'Update';

  @override
  String get rulesImportProblemFormat => 'not a rule object';

  @override
  String get rulesImportProblemMissingPattern => 'missing pattern';

  @override
  String get rulesExportAction => 'Export';

  @override
  String get rulesExportEmpty => 'There are no rules to export.';

  @override
  String rulesExportSaved(int count) {
    return 'Saved $count rules.';
  }

  @override
  String rulesExportSavedWithSkipped(int count, int skipped) {
    return 'Saved $count rules; $skipped unreadable rules were left out.';
  }

  @override
  String get rulesExportFailed => 'Could not export the rules.';

  @override
  String get rulesScopeBoth => 'title + body';

  @override
  String get rulesScopeContent => 'body only';

  @override
  String get rulesScopeTitle => 'title only';

  @override
  String get rulesScopeNone => 'not applied';

  @override
  String get bookSourceExportAll => 'Export all';

  @override
  String bookSourceExportSelected(int count) {
    return 'Export selected ($count)';
  }

  @override
  String bookSourceExportAllSaved(int count) {
    return 'Saved $count book sources.';
  }

  @override
  String get bookSourceExportEmpty => 'There are no book sources to export.';

  @override
  String get rulesListMenu => 'More';

  @override
  String get mySectionData => 'Data';

  @override
  String get cacheManageTitle => 'Cached chapters';

  @override
  String get cacheManageMore => 'More';

  @override
  String cacheManageTotal(int count) {
    return '$count cached chapters in total';
  }

  @override
  String cacheManageSourceCount(int count) {
    return '$count chapters';
  }

  @override
  String get cacheManageClearSource => 'Clear this source';

  @override
  String get cacheManageClearExpired => 'Clear expired entries';

  @override
  String get cacheManageClearAll => 'Clear the whole cache';

  @override
  String get cacheManageClearAllTitle => 'Clear the whole cache?';

  @override
  String get cacheManageClearAllBody =>
      'Cached chapters and probe results are downloaded again when needed.';

  @override
  String get cacheManageEmpty => 'Nothing is cached.';

  @override
  String get cacheManageLoadFailed => 'The cache could not be read.';

  @override
  String get myCookies => 'Cookies';

  @override
  String get myCookiesBody => 'What sites stored to keep you signed in';

  @override
  String get cookieManageTitle => 'Cookies';

  @override
  String get cookieManageMore => 'More';

  @override
  String get cookieManageSession => 'Until the app closes';

  @override
  String cookieManageExpiresAt(String moment) {
    return 'Expires $moment';
  }

  @override
  String get cookieManageDelete => 'Delete this cookie';

  @override
  String get cookieManageClearDomain => 'Clear this domain';

  @override
  String get cookieManageClearExpired => 'Clear expired cookies';

  @override
  String get cookieManageClearAll => 'Clear all cookies';

  @override
  String get cookieManageClearAllTitle => 'Clear all cookies?';

  @override
  String get cookieManageClearAllBody =>
      'Every site will ask you to sign in again.';

  @override
  String get cookieManageEmpty => 'No cookies are stored.';

  @override
  String get cookieManageLoadFailed => 'The cookies could not be read.';

  @override
  String get bookSourceLoginTitle => 'Sign in';

  @override
  String get bookSourceLoginLoadFailed => 'The login form could not be read.';

  @override
  String get bookSourceLoginNoForm => 'This source declares no login form.';

  @override
  String get bookSourceLoginWorking => 'Signing in…';

  @override
  String get bookSourceLoginDone =>
      'Signed in. The source\'s own script reported success.';

  @override
  String get myBackup => 'Backup and restore';

  @override
  String get myBackupBody =>
      'Pack everything into one zip, or restore from one';

  @override
  String get backupTitle => 'Backup and restore';

  @override
  String get backupExportTitle => 'Export a backup';

  @override
  String get backupExportBody =>
      'Book sources, shelf, groups, bookmarks, reading records, rules and settings, packed into one zip.';

  @override
  String get backupRestoreTitle => 'Restore from a backup';

  @override
  String get backupRestoreBody =>
      'See what the archive holds first, then merge it into this device.';

  @override
  String get backupIncludeSecretsHint =>
      'The archive is a plain file and includes book-source login data. Keep it somewhere you trust.';

  @override
  String get backupWorkingExporting => 'Packing…';

  @override
  String get backupWorkingReading => 'Reading the archive…';

  @override
  String get backupWorkingRestoring => 'Restoring…';

  @override
  String get backupPreviewTitle => 'What the archive holds';

  @override
  String get backupPreviewEmpty => 'This archive holds no rows.';

  @override
  String get backupConfirmRestore => 'Merge into this device';

  @override
  String get backupMergeHint =>
      'Restoring only merges: anything this device has that the archive lacks stays as it is.';

  @override
  String get backupTableBookSources => 'Book sources';

  @override
  String get backupTableBooks => 'Shelf';

  @override
  String get backupTableReadingProgress => 'Reading progress';

  @override
  String get backupTableBookGroups => 'Groups';

  @override
  String get backupTableBookmarks => 'Bookmarks';

  @override
  String get backupTableReadRecords => 'Reading records';

  @override
  String get backupTableRules => 'Rules';

  @override
  String backupExported(String fileName, int count) {
    return 'Saved $fileName ($count rows).';
  }

  @override
  String backupPreviewMeta(String createdAt, String appVersion) {
    return 'Written $createdAt by version $appVersion.';
  }

  @override
  String backupPreviewPreferences(int count) {
    return '$count settings';
  }

  @override
  String backupRestored(int changed, int preferences) {
    return 'Merged: $changed rows written, $preferences settings.';
  }

  @override
  String get backupAutoTitle => 'Automatic backup';

  @override
  String get backupAutoBody =>
      'Backs up once a day at start-up when the last archive is older than a day.';

  @override
  String get backupRetentionTitle => 'Backups to keep';

  @override
  String get backupRetentionBody =>
      'Older archives beyond this count are deleted; only files this app wrote are removed.';

  @override
  String backupRetentionValue(int count) {
    return '$count files';
  }

  @override
  String get backupLocationTitle => 'Backup location';

  @override
  String get backupLocationPrivate => 'App private folder';

  @override
  String get backupLocationChoose => 'Choose a folder';

  @override
  String get backupLocationReset => 'Use the private folder';

  @override
  String get backupLocationFallback =>
      'The chosen folder is unavailable; archives go to the app\'s private folder for now.';

  @override
  String get backupPasswordTitle => 'Backup password';

  @override
  String get backupPasswordBody =>
      'When set, whole archives are encrypted (AES-256); the password lives in the system key store.';

  @override
  String get backupPasswordChange => 'Change the password';

  @override
  String get backupPasswordSet => 'Set a password';

  @override
  String get backupPasswordClear => 'Remove the password';

  @override
  String get backupPasswordStored => 'Set (archives are encrypted)';

  @override
  String get backupPasswordMissing => 'Not set (archives stay unencrypted)';

  @override
  String get backupPasswordStoreFailed =>
      'The key store is unavailable, so the password was not stored: archives stay unencrypted.';

  @override
  String get backupSaveToLocation => 'Save to the backup location';

  @override
  String get backupSaveAs => 'Save as…';

  @override
  String get backupRestoreFromFile => 'Restore from a file';

  @override
  String backupSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get backupRemoteTitle => 'Cloud backups';

  @override
  String get backupRemoteEmpty => 'No backup files on the server.';

  @override
  String get backupRemoteRestore => 'Restore from the cloud';

  @override
  String get backupRemoteDelete => 'Delete the cloud backup';

  @override
  String get backupCloudUpload => 'Upload the current backup';

  @override
  String get backupCloudRefresh => 'Refresh the cloud list';

  @override
  String get backupWebDavTitle => 'WebDAV';

  @override
  String get backupWebDavUrl => 'URL (collection)';

  @override
  String get backupWebDavUsername => 'User name';

  @override
  String get backupWebDavPassword => 'Password';

  @override
  String get backupWebDavSave => 'Save the WebDAV configuration';

  @override
  String get backupWebDavNotConfigured => 'WebDAV is not configured yet.';

  @override
  String get backupPasswordRequired =>
      'This archive is encrypted and needs its password.';

  @override
  String get backupPasswordPrompt => 'Enter the backup password';

  @override
  String get backupPasswordWrong => 'That password is wrong; try again.';

  @override
  String get backupMergeMode => 'Merge';

  @override
  String get backupOverwriteMode => 'Overwrite';

  @override
  String get backupOverwriteWarning =>
      'Overwriting clears this device\'s book sources, shelf, groups, bookmarks, reading records and rules first, then writes the archive; a safety copy is saved before it starts.';

  @override
  String get backupOverwriteConfirm => 'Overwrite this device';

  @override
  String backupSafetyCopy(String name) {
    return 'Safety copy saved first: $name';
  }

  @override
  String get backupWorkSavingAs => 'Saving…';

  @override
  String get backupWorkUploading => 'Uploading…';

  @override
  String get backupWorkListingRemote => 'Listing the cloud collection…';

  @override
  String get backupWorkDownloading => 'Downloading…';

  @override
  String get backupLocalTitle => 'On this device';

  @override
  String get settingsSeedColor => 'Colour';

  @override
  String get settingsSeedColorHint =>
      'Dynamic colour wins when the platform has it; this decides the colours on devices that do not.';

  @override
  String get settingsSeedColorDefault => 'Default';

  @override
  String get settingsBackgroundImage => 'Background';

  @override
  String get settingsBackgroundImageNone => 'Not set';

  @override
  String get settingsBackgroundImageChoose => 'Choose an image';

  @override
  String get settingsBackgroundImageRemove => 'Remove';

  @override
  String get settingsBackgroundImageHint =>
      'The image is copied into the app, so deleting the original is fine.';

  @override
  String get settingsBackgroundImageFailed =>
      'The background image could not be saved; try again.';
}
