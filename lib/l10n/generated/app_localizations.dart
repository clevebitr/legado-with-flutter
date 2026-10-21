import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application name shown in the task switcher and app bar.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get appTitle;

  /// Title of the book source list page.
  ///
  /// In en, this message translates to:
  /// **'Book sources'**
  String get bookSourceListTitle;

  /// Label of the retry action shown after a recoverable failure.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Label of the book source import action.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// Title of the book source search page.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get bookSourceSearchTitle;

  /// Hint of the search keyword field.
  ///
  /// In en, this message translates to:
  /// **'Title or author'**
  String get bookSourceSearchHint;

  /// Label of the search action, also used as its semantics label.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get bookSourceSearchAction;

  /// Empty state shown before the first search of a session.
  ///
  /// In en, this message translates to:
  /// **'Enter a keyword to search the book source.'**
  String get bookSourceSearchPrompt;

  /// Empty state shown when a search returned no results.
  ///
  /// In en, this message translates to:
  /// **'No book matched this keyword.'**
  String get bookSourceSearchEmpty;

  /// No description provided for @bookSourceMissingSource.
  ///
  /// In en, this message translates to:
  /// **'No book source is stored yet. Import one to start reading.'**
  String get bookSourceMissingSource;

  /// Title of the book detail page.
  ///
  /// In en, this message translates to:
  /// **'Book details'**
  String get bookSourceDetailTitle;

  /// Heading of the chapter list on the book detail page.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get bookSourceTocTitle;

  /// Reader title, used when a chapter has an empty name.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get bookSourceReaderTitle;

  /// Author row on the book detail page.
  ///
  /// In en, this message translates to:
  /// **'Author: {author}'**
  String bookSourceAuthorLine(String author);

  /// Category row on the book detail page.
  ///
  /// In en, this message translates to:
  /// **'Category: {kind}'**
  String bookSourceKindLine(String kind);

  /// Latest-chapter row on the book detail page.
  ///
  /// In en, this message translates to:
  /// **'Latest chapter: {chapter}'**
  String bookSourceLastChapterLine(String chapter);

  /// User-facing message for ParseFailureKind.networkTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again later.'**
  String get failureNetworkTimeout;

  /// User-facing message for ParseFailureKind.networkFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check your network and try again.'**
  String get failureNetworkFailed;

  /// User-facing message for ParseFailureKind.networkForbidden.
  ///
  /// In en, this message translates to:
  /// **'The site refused access (403). The book source may need an update.'**
  String get failureNetworkForbidden;

  /// User-facing message for ParseFailureKind.notFound.
  ///
  /// In en, this message translates to:
  /// **'The requested page was not found (404). The book source may be broken.'**
  String get failureNotFound;

  /// User-facing message for ParseFailureKind.encodingFailed.
  ///
  /// In en, this message translates to:
  /// **'The page encoding could not be detected.'**
  String get failureEncodingFailed;

  /// User-facing message for ParseFailureKind.parseFailed.
  ///
  /// In en, this message translates to:
  /// **'Parsing failed. The book source rules may be out of date.'**
  String get failureParseFailed;

  /// User-facing message for ParseFailureKind.invalidBookSource.
  ///
  /// In en, this message translates to:
  /// **'This file is not a valid book source.'**
  String get failureInvalidBookSource;

  /// Title of the legal notices screen required by GPL-3.0 section 0.
  ///
  /// In en, this message translates to:
  /// **'Legal notices'**
  String get legalNoticesTitle;

  /// Copyright line shown on the legal notices screen.
  ///
  /// In en, this message translates to:
  /// **'flutter_reader, Copyright (C) 2026 Clevebitr.'**
  String get legalNoticesCopyright;

  /// No-warranty and redistribution notice required by GPL-3.0 section 5d.
  ///
  /// In en, this message translates to:
  /// **'This program comes with ABSOLUTELY NO WARRANTY. It is free software licensed under the GNU GPL-3.0, and you are welcome to redistribute it under certain conditions.'**
  String get legalNoticesNoWarranty;

  /// Action that opens the bundled GPL-3.0 license text.
  ///
  /// In en, this message translates to:
  /// **'View the full license'**
  String get legalNoticesViewLicense;

  /// Action that opens the source code location required by GPL-3.0 section 6.
  ///
  /// In en, this message translates to:
  /// **'Corresponding source code'**
  String get legalNoticesCorrespondingSource;

  /// Prohibited-use notice shown on the legal notices screen; records the stance of ADR-0023.
  ///
  /// In en, this message translates to:
  /// **'Do not use this app to infringe copyright. Scraping, aggregating or redistributing unauthorised content through book sources is prohibited, and anyone doing so bears the full legal responsibility.'**
  String get legalNoticesProhibitedUse;

  /// User-facing message for ParseFailureKind.unsupportedRule.
  ///
  /// In en, this message translates to:
  /// **'This book source uses a rule type that is not supported yet.'**
  String get failureUnsupportedRule;

  /// Title of the discover (exploreUrl) page.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get bookSourceExploreTitle;

  /// Tooltip of the button that opens the discover page.
  ///
  /// In en, this message translates to:
  /// **'Discover page'**
  String get bookSourceExploreAction;

  /// Shown on the discover page before a category is opened.
  ///
  /// In en, this message translates to:
  /// **'Pick a category to start browsing'**
  String get bookSourceExplorePrompt;

  /// Empty state: the source declares no exploreUrl categories.
  ///
  /// In en, this message translates to:
  /// **'This book source has no discover categories'**
  String get bookSourceExploreEmpty;

  /// Shown when a discover category's page listed no usable book; distinct from bookSourceSearchEmpty, which mentions a keyword this screen never has.
  ///
  /// In en, this message translates to:
  /// **'This category has no books.'**
  String get bookSourceExploreEmptyCategory;

  /// Summary after an import where every entry was accepted.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} book sources.'**
  String bookSourceImportSucceeded(int count);

  /// Summary after an import where some entries were skipped; the reasons are logged, never shown per entry.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} book sources; {skipped} entries were skipped as invalid.'**
  String bookSourceImportPartiallySkipped(int count, int skipped);

  /// Label of the button that dismisses a confirmation without acting.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Label of the destructive action (a stored book source, a cache entry).
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Button of the empty state that opens the book source list.
  ///
  /// In en, this message translates to:
  /// **'Manage book sources'**
  String get bookSourceMissingSourceAction;

  /// Empty state of the book source list; the import button below it is the way in.
  ///
  /// In en, this message translates to:
  /// **'No book source is stored yet.'**
  String get bookSourceListEmpty;

  /// Shown when reading the stored book sources failed; the retry button reloads them.
  ///
  /// In en, this message translates to:
  /// **'The stored book sources could not be read.'**
  String get bookSourceListLoadFailed;

  /// Accessible label of the marker on the row the pages currently use.
  ///
  /// In en, this message translates to:
  /// **'Current book source'**
  String get bookSourceCurrentLabel;

  /// Subtitle line on a row whose bookSourceUrl is shared by another stored source, so the two rows are not read as duplicates.
  ///
  /// In en, this message translates to:
  /// **'Same site, another rule set'**
  String get bookSourceVariantLabel;

  /// Title of the confirmation before deleting one stored book source.
  ///
  /// In en, this message translates to:
  /// **'Delete this book source?'**
  String get bookSourceListDeleteTitle;

  /// Body of the delete confirmation; the name is the source name and never a user keyword.
  ///
  /// In en, this message translates to:
  /// **'{name} and its stored rules will be removed.'**
  String bookSourceListDeleteBody(String name);

  /// Title of the import screen.
  ///
  /// In en, this message translates to:
  /// **'Import book sources'**
  String get bookSourceImportTitle;

  /// Label of the field that takes a pasted JSON document.
  ///
  /// In en, this message translates to:
  /// **'Book source JSON'**
  String get bookSourceImportTextLabel;

  /// Hint of the paste field.
  ///
  /// In en, this message translates to:
  /// **'Paste an exported book source file here'**
  String get bookSourceImportTextHint;

  /// Label of the field that downloads a book source file.
  ///
  /// In en, this message translates to:
  /// **'Or a URL'**
  String get bookSourceImportUrlLabel;

  /// Hint of the URL field; an example address, not a real source.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/sources.json'**
  String get bookSourceImportUrlHint;

  /// Label of the button that opens the platform file dialog on the import screen.
  ///
  /// In en, this message translates to:
  /// **'Choose a JSON file'**
  String get bookSourceImportFileAction;

  /// Title of the bookshelf page, also used as the tooltip of its entry button.
  ///
  /// In en, this message translates to:
  /// **'Bookshelf'**
  String get shelfTitle;

  /// Empty state of the bookshelf page.
  ///
  /// In en, this message translates to:
  /// **'Your shelf is empty. Open a book\'s details and choose “Add to shelf”.'**
  String get shelfEmpty;

  /// Shown when reading the shelf from storage failed.
  ///
  /// In en, this message translates to:
  /// **'The shelf could not be loaded.'**
  String get shelfLoadFailed;

  /// Shelf label for a book the user is still following.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get shelfStatusTracking;

  /// Shelf label for a book the user has finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get shelfStatusRead;

  /// Menu action that pins a shelf entry above the others.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get shelfActionPin;

  /// Menu action that removes the pin of a shelf entry.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get shelfActionUnpin;

  /// Menu action that moves a shelf entry to the finished group.
  ///
  /// In en, this message translates to:
  /// **'Mark as finished'**
  String get shelfActionMarkRead;

  /// Menu action that moves a shelf entry back to the reading group.
  ///
  /// In en, this message translates to:
  /// **'Mark as reading'**
  String get shelfActionMarkTracking;

  /// Menu action that deletes a shelf entry.
  ///
  /// In en, this message translates to:
  /// **'Remove from shelf'**
  String get shelfActionRemove;

  /// Title of the confirmation dialog before a shelf entry is deleted.
  ///
  /// In en, this message translates to:
  /// **'Remove this book?'**
  String get shelfRemoveTitle;

  /// Body of the confirmation dialog before a shelf entry is deleted.
  ///
  /// In en, this message translates to:
  /// **'Its reading progress is removed too.'**
  String get shelfRemoveBody;

  /// Subtitle of a shelf entry that was opened before.
  ///
  /// In en, this message translates to:
  /// **'Reading: {chapter}'**
  String shelfProgressLine(String chapter);

  /// Label of the button on the book detail page that puts the book on the shelf.
  ///
  /// In en, this message translates to:
  /// **'Add to shelf'**
  String get shelfAddAction;

  /// Snackbar shown after a book was added to the shelf.
  ///
  /// In en, this message translates to:
  /// **'Added to the shelf.'**
  String get shelfAddSucceeded;

  /// Shown when writing a book to the shelf failed.
  ///
  /// In en, this message translates to:
  /// **'The book could not be added to the shelf.'**
  String get shelfAddFailed;

  /// Shown when pinning, re-grouping or removing a shelf entry failed.
  ///
  /// In en, this message translates to:
  /// **'The shelf could not be updated.'**
  String get shelfWriteFailed;

  /// Tooltip of a stepper button that lowers a numeric setting.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get actionDecrease;

  /// Tooltip of a stepper button that raises a numeric setting.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get actionIncrease;

  /// Title of the settings page, also used as the tooltip of its entry button.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Shown when reading the stored settings failed.
  ///
  /// In en, this message translates to:
  /// **'The settings could not be loaded.'**
  String get settingsLoadFailed;

  /// Label of the theme mode setting.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// Theme mode that follows the platform.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsThemeSystem;

  /// Theme mode that always uses the light scheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Theme mode that always uses the dark scheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Label of the default text scale setting.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsFontScale;

  /// Current text scale shown next to its slider.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String settingsFontScaleValue(int percent);

  /// Label of the per-source concurrency budget setting.
  ///
  /// In en, this message translates to:
  /// **'Concurrent requests per source'**
  String get settingsConcurrency;

  /// Explanation under the concurrency setting, including its allowed range.
  ///
  /// In en, this message translates to:
  /// **'1 to 8. Higher values are faster and less polite to the site.'**
  String get settingsConcurrencyHint;

  /// Section title of the cache actions.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get settingsCache;

  /// Action that removes every cached entry.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get settingsClearCache;

  /// Title of the confirmation dialog before clearing the cache.
  ///
  /// In en, this message translates to:
  /// **'Clear the whole cache?'**
  String get settingsClearCacheTitle;

  /// Body of the confirmation dialog before clearing the cache.
  ///
  /// In en, this message translates to:
  /// **'Cached pages and chapter bodies are downloaded again when needed.'**
  String get settingsClearCacheBody;

  /// Snackbar shown after the cache was cleared.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} cached entries.'**
  String settingsCacheCleared(int count);

  /// Title of the batch book source check page.
  ///
  /// In en, this message translates to:
  /// **'Check book sources'**
  String get bookSourceCheckTitle;

  /// Description of what the batch check does.
  ///
  /// In en, this message translates to:
  /// **'Each source runs through search, discover, details, chapters and body.'**
  String get bookSourceCheckIntro;

  /// Label above the stage switches.
  ///
  /// In en, this message translates to:
  /// **'Stages'**
  String get bookSourceCheckStages;

  /// Label of the search stage switch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get bookSourceCheckStageSearch;

  /// Label of the discover stage switch.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get bookSourceCheckStageExplore;

  /// Label of the book detail stage switch.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get bookSourceCheckStageInfo;

  /// Label of the chapter list stage switch.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get bookSourceCheckStageToc;

  /// Label of the chapter body stage switch.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get bookSourceCheckStageContent;

  /// Label of the keyword field used by the search stage.
  ///
  /// In en, this message translates to:
  /// **'Keyword'**
  String get bookSourceCheckKeyword;

  /// Hint of the keyword field.
  ///
  /// In en, this message translates to:
  /// **'Keyword sent to every checked source'**
  String get bookSourceCheckKeywordHint;

  /// Label of the per-source timeout row.
  ///
  /// In en, this message translates to:
  /// **'Timeout per source'**
  String get bookSourceCheckTimeout;

  /// Label of the button that starts the batch.
  ///
  /// In en, this message translates to:
  /// **'Start check'**
  String get bookSourceCheckStart;

  /// Label of the button that cancels the batch.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get bookSourceCheckStop;

  /// Empty state of the check page.
  ///
  /// In en, this message translates to:
  /// **'No book source is stored yet. Import one to check it.'**
  String get bookSourceCheckEmpty;

  /// Shown when the batch starts with nothing selected.
  ///
  /// In en, this message translates to:
  /// **'Select at least one book source.'**
  String get bookSourceCheckSelectionEmpty;

  /// Per-source status while the batch has not reached it.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get bookSourceCheckStatusPending;

  /// Per-source status while its check runs.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get bookSourceCheckStatusRunning;

  /// Per-source status after a healthy check.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get bookSourceCheckStatusSucceeded;

  /// Per-source status after a check that found problems.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get bookSourceCheckStatusFailed;

  /// Per-source status after the user stopped the batch.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get bookSourceCheckStatusCancelled;

  /// Reason shown when the check failed.
  ///
  /// In en, this message translates to:
  /// **'The check found problems.'**
  String get bookSourceCheckFailureCheckFailed;

  /// Reason shown when the row is gone.
  ///
  /// In en, this message translates to:
  /// **'The source was deleted meanwhile.'**
  String get bookSourceCheckFailureSourceMissing;

  /// Reason shown when the write-back failed.
  ///
  /// In en, this message translates to:
  /// **'The result could not be saved.'**
  String get bookSourceCheckFailureSaveFailed;

  /// Line naming the failing rule of a stage.
  ///
  /// In en, this message translates to:
  /// **'Failed at {rulePath}'**
  String bookSourceCheckFailedAt(String rulePath);

  /// Line showing how long a source's check took.
  ///
  /// In en, this message translates to:
  /// **'Took {millis} ms'**
  String bookSourceCheckElapsed(int millis);

  /// Tooltip of the action that opens the debug console.
  ///
  /// In en, this message translates to:
  /// **'Debug this source'**
  String get bookSourceCheckOpenDebug;

  /// Label of the action that selects every listed source.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get bookSourceCheckSelectAll;

  /// Label of the action that clears the selection.
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get bookSourceCheckSelectNone;

  /// Title of the single-source debug console.
  ///
  /// In en, this message translates to:
  /// **'Debug a book source'**
  String get bookSourceDebugTitle;

  /// Label above the target selector.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get bookSourceDebugTarget;

  /// Debug target label.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get bookSourceDebugTargetSearch;

  /// Debug target label.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get bookSourceDebugTargetExplore;

  /// Debug target label.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get bookSourceDebugTargetInfo;

  /// Debug target label.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get bookSourceDebugTargetToc;

  /// Debug target label.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get bookSourceDebugTargetContent;

  /// Label of the debug query field.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get bookSourceDebugQuery;

  /// Hint of the query field for the search target.
  ///
  /// In en, this message translates to:
  /// **'Keyword to search for'**
  String get bookSourceDebugQueryKeywordHint;

  /// Hint of the query field for the URL targets.
  ///
  /// In en, this message translates to:
  /// **'Page URL'**
  String get bookSourceDebugQueryUrlHint;

  /// Label above the example chips.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get bookSourceDebugExamples;

  /// Label of the button that runs the target.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get bookSourceDebugStart;

  /// Label of the button that cancels the run.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get bookSourceDebugStop;

  /// Label of the button that empties the event list.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get bookSourceDebugClear;

  /// Empty state of the event list.
  ///
  /// In en, this message translates to:
  /// **'No event yet. Run a target to see the chain.'**
  String get bookSourceDebugEmpty;

  /// Run status while the target is running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get bookSourceDebugStatusRunning;

  /// Run status after the target read something.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get bookSourceDebugStatusSucceeded;

  /// Run status after the target failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get bookSourceDebugStatusFailed;

  /// Run status after the user stopped the run.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get bookSourceDebugStatusCancelled;

  /// Label of a message line.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get bookSourceDebugEventMessage;

  /// Label of a source line.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get bookSourceDebugEventSource;

  /// Label of an error line.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get bookSourceDebugEventError;

  /// Shown when the debug route names a source that no longer exists.
  ///
  /// In en, this message translates to:
  /// **'Choose a book source on the source list first.'**
  String get bookSourceDebugMissingSource;

  /// Run status before anything has been started.
  ///
  /// In en, this message translates to:
  /// **'Not run yet'**
  String get bookSourceDebugStatusIdle;

  /// Action that opens the chapter list of the reader.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get readerTocAction;

  /// Action that opens the reader settings sheet.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get readerSettingsAction;

  /// Label of the reader font size slider.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get readerFontSize;

  /// Label of the reader line height slider.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get readerLineHeight;

  /// Label of the reader background choices.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get readerBackground;

  /// Reader background that follows the theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get readerBackgroundSystem;

  /// Reader background with a warm paper tone.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get readerBackgroundPaper;

  /// Reader background with a sepia tone.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get readerBackgroundSepia;

  /// Reader background for night reading.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get readerBackgroundDark;

  /// Label of the page mode switch.
  ///
  /// In en, this message translates to:
  /// **'Turn pages'**
  String get readerPageMode;

  /// Reader page mode that scrolls the body.
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get readerPageModeScroll;

  /// Reader page mode that splits the body into pages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get readerPageModePaged;

  /// Action that opens the previous chapter.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get readerPreviousChapter;

  /// Action that opens the next chapter.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get readerNextChapter;

  /// Shown on the last page of a chapter in paged mode.
  ///
  /// In en, this message translates to:
  /// **'End of this chapter'**
  String get readerChapterEnd;

  /// Shown when the open chapter is the last one.
  ///
  /// In en, this message translates to:
  /// **'This is the last chapter'**
  String get readerLastChapter;

  /// Shown when the chapter list came back empty.
  ///
  /// In en, this message translates to:
  /// **'This book has no readable chapter.'**
  String get readerNoChapter;

  /// Foot line showing the update time a rule returned.
  ///
  /// In en, this message translates to:
  /// **'Updated: {value}'**
  String bookSourceUpdateTimeLine(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
