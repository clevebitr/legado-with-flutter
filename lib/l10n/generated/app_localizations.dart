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

  /// Bottom navigation: the bookshelf tab.
  ///
  /// In en, this message translates to:
  /// **'Shelf'**
  String get shellTabBookshelf;

  /// Bottom navigation: the discover tab.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get shellTabExplore;

  /// Bottom navigation: the aggregated search tab.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get shellTabSearch;

  /// Bottom navigation: the entry-aggregator tab.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get shellTabMy;

  /// Title of the Me page.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get myTitle;

  /// Me page section label for content-related entries.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get mySectionContent;

  /// Me page section label for app-level entries.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get mySectionApp;

  /// Me page entry: opens book-source management.
  ///
  /// In en, this message translates to:
  /// **'Book sources'**
  String get myBookSources;

  /// Me page entry subtitle for book sources.
  ///
  /// In en, this message translates to:
  /// **'Import, check and group'**
  String get myBookSourcesBody;

  /// Title of the about page.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// About page: the app version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// About page entry: opens the legal notices page.
  ///
  /// In en, this message translates to:
  /// **'Licenses and legal notices'**
  String get aboutLicenses;

  /// About page: where the Corresponding Source is published.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSourceCode;

  /// Copies the source-code address.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get aboutCopySource;

  /// Confirmation after copying the source-code address.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get aboutCopied;

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

  /// Title of the page that shows the bundled GPL-3.0 text.
  ///
  /// In en, this message translates to:
  /// **'GNU GPL-3.0'**
  String get legalNoticesLicenseTitle;

  /// Shown when the bundled license asset cannot be read.
  ///
  /// In en, this message translates to:
  /// **'The license text could not be loaded. Reopen this page to try again.'**
  String get legalNoticesLicenseFailed;

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

  /// Preview summary: how the file splits into new, refresh and rejected entries.
  ///
  /// In en, this message translates to:
  /// **'{newCount} new · {refreshCount} to refresh · {rejected} rejected'**
  String bookSourceImportPreviewSummary(
    int newCount,
    int refreshCount,
    int rejected,
  );

  /// Preview entry label: this identity is not stored yet.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get bookSourceImportEntryNew;

  /// Preview entry label: the same identity is stored and only its payload will be refreshed.
  ///
  /// In en, this message translates to:
  /// **'Already imported · will refresh'**
  String get bookSourceImportEntryRefresh;

  /// Preview entry title when the entry has no readable name.
  ///
  /// In en, this message translates to:
  /// **'Entry {index}'**
  String bookSourceImportEntryUnknown(int index);

  /// Preview rejection: the entry has no usable bookSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Missing bookSourceUrl'**
  String get bookSourceImportRejectionMissingUrl;

  /// Preview rejection: the entry has no usable bookSourceName.
  ///
  /// In en, this message translates to:
  /// **'Missing bookSourceName'**
  String get bookSourceImportRejectionMissingName;

  /// Preview rejection: a required rule object or another structural field is unreadable.
  ///
  /// In en, this message translates to:
  /// **'This entry cannot be read as a book source'**
  String get bookSourceImportRejectionUnreadable;

  /// Preview rejection: the element of the file is not a JSON object.
  ///
  /// In en, this message translates to:
  /// **'Not a JSON object'**
  String get bookSourceImportRejectionNotAnObject;

  /// Preview action: stores the ticked entries.
  ///
  /// In en, this message translates to:
  /// **'Import selected ({count})'**
  String bookSourceImportCommit(int count);

  /// Preview action: ticks every usable entry.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get bookSourceImportSelectAll;

  /// Preview action: unticks every entry.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get bookSourceImportDeselectAll;

  /// Preview action: drops the preview without storing anything.
  ///
  /// In en, this message translates to:
  /// **'Back to the form'**
  String get bookSourceImportBack;

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

  /// Name of the Android notification channel used by the batch check.
  ///
  /// In en, this message translates to:
  /// **'Book source check'**
  String get bookSourceCheckNotificationChannel;

  /// Title of the ongoing notification shown while a batch check runs.
  ///
  /// In en, this message translates to:
  /// **'Checking book sources'**
  String get bookSourceCheckNotificationTitle;

  /// Line of the ongoing check notification: the source being checked and the progress.
  ///
  /// In en, this message translates to:
  /// **'{name} · {completed}/{total}'**
  String bookSourceCheckNotificationProgress(
    String name,
    int completed,
    int total,
  );

  /// Text of the notification shown when a batch check finishes.
  ///
  /// In en, this message translates to:
  /// **'Check finished: {succeeded} passed, {failed} failed'**
  String bookSourceCheckNotificationFinished(int succeeded, int failed);

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

  /// Reader setting: strength of the blue-light reducing filter over the page.
  ///
  /// In en, this message translates to:
  /// **'Warm filter'**
  String get readerEyeProtection;

  /// Reader setting: whether the display stays awake while reading.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen on'**
  String get readerKeepAwake;

  /// Reader setting: the line at the bottom with chapter, progress, time and charge.
  ///
  /// In en, this message translates to:
  /// **'Show the status line'**
  String get readerStatusLine;

  /// Charge shown in the reader's status line.
  ///
  /// In en, this message translates to:
  /// **'{percent}% battery'**
  String readerBatteryLevel(int percent);

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

  /// Shown where a chapter that has not arrived yet will appear.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get readerChapterLoading;

  /// Action that tries to read a neighbouring chapter again.
  ///
  /// In en, this message translates to:
  /// **'Reload this chapter'**
  String get readerChapterRetry;

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

  /// Manga reader: which page of the chapter is on screen.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String mangaPageIndicator(int current, int total);

  /// Manga reader: one image could not be loaded; the tile offers a retry.
  ///
  /// In en, this message translates to:
  /// **'This page failed to load.'**
  String get mangaImageFailed;

  /// Foot line showing the update time a rule returned.
  ///
  /// In en, this message translates to:
  /// **'Updated: {value}'**
  String bookSourceUpdateTimeLine(String value);

  /// Tooltip of the sort menu on the source list.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get bookSourceListSortLabel;

  /// Sort key: the manual order a drag writes.
  ///
  /// In en, this message translates to:
  /// **'Manual order'**
  String get bookSourceListSortDefault;

  /// Sort key: the weight the source declares.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get bookSourceListSortWeight;

  /// Sort key: the duration of the last check.
  ///
  /// In en, this message translates to:
  /// **'Response time'**
  String get bookSourceListSortRespondTime;

  /// Sort key: the source name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get bookSourceListSortName;

  /// Filter chip that shows every group.
  ///
  /// In en, this message translates to:
  /// **'All groups'**
  String get bookSourceListGroupAll;

  /// Response time of a source, in milliseconds.
  ///
  /// In en, this message translates to:
  /// **'{millis} ms'**
  String bookSourceListRespondTimeLine(int millis);

  /// Title of the dialog that shows a source note.
  ///
  /// In en, this message translates to:
  /// **'Check note'**
  String get bookSourceListCommentTitle;

  /// Menu action that opens the source note.
  ///
  /// In en, this message translates to:
  /// **'View note'**
  String get bookSourceListCommentAction;

  /// Empty state when the group filter hides every source.
  ///
  /// In en, this message translates to:
  /// **'No source matches this group.'**
  String get bookSourceListNoMatch;

  /// Tooltip of the search scope button.
  ///
  /// In en, this message translates to:
  /// **'Search in'**
  String get searchScopeLabel;

  /// Scope option: every enabled source.
  ///
  /// In en, this message translates to:
  /// **'All enabled sources'**
  String get searchScopeAll;

  /// Shown after a search ran because the picked scope (a deleted group or a removed source) named nothing any more.
  ///
  /// In en, this message translates to:
  /// **'That scope no longer exists, so every enabled source was searched.'**
  String get searchScopeFellBack;

  /// Scope chip label when specific sources are chosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen sources'**
  String get searchScopeNamed;

  /// Tooltip of the search filter button.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFilterLabel;

  /// Label above the source-type check boxes.
  ///
  /// In en, this message translates to:
  /// **'Source types'**
  String get searchTypeLabel;

  /// Source type: text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get searchTypeText;

  /// Source type: audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get searchTypeAudio;

  /// Source type: image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get searchTypeImage;

  /// Source type: file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get searchTypeFile;

  /// Label above the match mode choices.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get searchMatchLabel;

  /// Match mode: keep everything, exact first.
  ///
  /// In en, this message translates to:
  /// **'Fuzzy'**
  String get searchMatchDefault;

  /// Match mode: only hits whose name or author equals the keyword.
  ///
  /// In en, this message translates to:
  /// **'Exact name or author'**
  String get searchMatchExact;

  /// Search progress line.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} sources'**
  String searchProgress(int done, int total);

  /// Line shown when some sources failed.
  ///
  /// In en, this message translates to:
  /// **'{failed} sources failed'**
  String searchPartialFailed(int failed);

  /// Action that pauses the running search.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get searchPause;

  /// Action that resumes a paused search.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get searchResume;

  /// Action that stops the running search.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get searchStop;

  /// Action that asks every page-capable source for the next page.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get searchLoadMore;

  /// How many sources found one book.
  ///
  /// In en, this message translates to:
  /// **'{count} sources'**
  String searchOriginsLine(int count);

  /// Shown when the scope resolves to no searchable source.
  ///
  /// In en, this message translates to:
  /// **'No source can be searched in this scope.'**
  String get searchNoSources;

  /// Source type: video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get searchTypeVideo;

  /// Detail page action: opens the reader at the first chapter.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get bookSourceStartReading;

  /// Detail page action: opens the reader at the stored position.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get bookSourceContinueReading;

  /// Expands the truncated introduction on the detail page.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get bookSourceIntroExpand;

  /// Collapses the expanded introduction on the detail page.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get bookSourceIntroCollapse;

  /// Search field on the source list.
  ///
  /// In en, this message translates to:
  /// **'Search name, URL or group'**
  String get bookSourceListSearchHint;

  /// Selection mode: selects every visible row.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get bookSourceListSelectAll;

  /// Selection mode: inverts the current selection.
  ///
  /// In en, this message translates to:
  /// **'Invert'**
  String get bookSourceListInvertSelection;

  /// Toolbar action: enters the multi-select mode with nothing ticked yet.
  ///
  /// In en, this message translates to:
  /// **'Select sources'**
  String get bookSourceListSelectMode;

  /// One-click action next to the failing filter: disables every failing source currently listed.
  ///
  /// In en, this message translates to:
  /// **'Disable failing'**
  String get bookSourceListInvalidDisable;

  /// One-click action next to the failing filter: deletes every failing source currently listed, after a confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete failing'**
  String get bookSourceListInvalidDelete;

  /// Feedback after the one-click disable.
  ///
  /// In en, this message translates to:
  /// **'Disabled {count} failing sources'**
  String bookSourceListInvalidDisabled(int count);

  /// Confirmation title of the one-click delete for failing sources.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} failing sources?'**
  String bookSourceListInvalidDeleteTitle(int count);

  /// Group dialog action: switches the list to the group and ticks all of its sources.
  ///
  /// In en, this message translates to:
  /// **'Select every source in this group'**
  String get bookSourceListGroupSelectSources;

  /// Group dialog action: deletes the sources of the group, not just the group label.
  ///
  /// In en, this message translates to:
  /// **'Delete every source in this group'**
  String get bookSourceListGroupDeleteSources;

  /// Confirmation title for deleting every source of a group.
  ///
  /// In en, this message translates to:
  /// **'Delete the {count} sources in “{group}”?'**
  String bookSourceListGroupDeleteSourcesTitle(int count, String group);

  /// Selection mode: how many rows are selected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String bookSourceListSelectedCount(int count);

  /// Batch action: opens the check page with exactly the selected sources ticked.
  ///
  /// In en, this message translates to:
  /// **'Check selected'**
  String get bookSourceListBatchCheck;

  /// Batch action: enables every selected source.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get bookSourceListBatchEnable;

  /// Batch action: disables every selected source.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get bookSourceListBatchDisable;

  /// Batch action: deletes every selected source.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get bookSourceListBatchDelete;

  /// Confirmation title for a batch delete.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} sources?'**
  String bookSourceListBatchDeleteTitle(int count);

  /// Confirmation body for a batch delete.
  ///
  /// In en, this message translates to:
  /// **'Books you added from them stay on the shelf.'**
  String get bookSourceListBatchDeleteBody;

  /// Batch action: puts the selection into a group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get bookSourceListBatchGroup;

  /// Group picker: clears the group.
  ///
  /// In en, this message translates to:
  /// **'No group'**
  String get bookSourceListGroupNone;

  /// Group picker: asks for a new group name.
  ///
  /// In en, this message translates to:
  /// **'New group…'**
  String get bookSourceListGroupNew;

  /// Text field hint for a group name.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get bookSourceListGroupNameHint;

  /// Chip row label for the check-status filter.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get bookSourceCheckFilterLabel;

  /// Check-status filter: every source.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get bookSourceCheckFilterAll;

  /// Check-status filter: sources with no failure group or note.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get bookSourceCheckFilterHealthy;

  /// Check-status filter: sources whose last check failed.
  ///
  /// In en, this message translates to:
  /// **'Has failures'**
  String get bookSourceCheckFilterFailing;

  /// Status light: the last check found no failure.
  ///
  /// In en, this message translates to:
  /// **'Check passed'**
  String get bookSourceCheckStatusPassed;

  /// Status light: the last check failed only with a timeout or a broken script.
  ///
  /// In en, this message translates to:
  /// **'Timed out or JS failed'**
  String get bookSourceCheckStatusDegraded;

  /// Status light: the source has no verdict yet.
  ///
  /// In en, this message translates to:
  /// **'Never checked'**
  String get bookSourceCheckStatusUnchecked;

  /// Last-check summary: the check finished less than a minute ago.
  ///
  /// In en, this message translates to:
  /// **'Checked just now'**
  String get bookSourceListLastCheckJustNow;

  /// Last-check summary: minutes since the last verdict.
  ///
  /// In en, this message translates to:
  /// **'Checked {count} min ago'**
  String bookSourceListLastCheckMinutesAgo(int count);

  /// Last-check summary: hours since the last verdict.
  ///
  /// In en, this message translates to:
  /// **'Checked {count} h ago'**
  String bookSourceListLastCheckHoursAgo(int count);

  /// Last-check summary: days since the last verdict.
  ///
  /// In en, this message translates to:
  /// **'Checked {count} d ago'**
  String bookSourceListLastCheckDaysAgo(int count);

  /// Last-check summary: absolute date for a verdict older than a week.
  ///
  /// In en, this message translates to:
  /// **'Checked {date}'**
  String bookSourceListLastCheckOn(String date);

  /// Last-check summary: when it ran and how long it took.
  ///
  /// In en, this message translates to:
  /// **'{when} · {millis} ms'**
  String bookSourceListLastCheckLine(String when, int millis);

  /// Batch action: moves the selection to the top of the manual order.
  ///
  /// In en, this message translates to:
  /// **'Move to top'**
  String get bookSourceListBatchMoveTop;

  /// Batch action: moves the selection to the bottom of the manual order.
  ///
  /// In en, this message translates to:
  /// **'Move to bottom'**
  String get bookSourceListBatchMoveBottom;

  /// Batch action: removes the selection from the current group filter.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get bookSourceListBatchRemoveGroup;

  /// Row badge: the source offers its discover page.
  ///
  /// In en, this message translates to:
  /// **'Discover on'**
  String get bookSourceListExploreOn;

  /// Row badge: the user turned the discover page off.
  ///
  /// In en, this message translates to:
  /// **'Discover off'**
  String get bookSourceListExploreOff;

  /// Discover page empty state: the user disabled this source's discover page.
  ///
  /// In en, this message translates to:
  /// **'Discover is turned off for this source. Turn it back on in the source list.'**
  String get bookSourceExploreDisabled;

  /// Row menu: offers the source's discover page again.
  ///
  /// In en, this message translates to:
  /// **'Turn discover on'**
  String get bookSourceRowExploreEnable;

  /// Row menu: hides the source's discover page without deleting its rules.
  ///
  /// In en, this message translates to:
  /// **'Turn discover off'**
  String get bookSourceRowExploreDisable;

  /// Sort direction toggle: current direction is ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get bookSourceListSortAscending;

  /// Sort direction toggle: current direction is descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get bookSourceListSortDescending;

  /// List view toggle: one section per book source host.
  ///
  /// In en, this message translates to:
  /// **'Group by domain'**
  String get bookSourceListGroupByDomain;

  /// Tooltip of the list's view-options menu.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get bookSourceListViewOptions;

  /// Tooltip of the batch bar's overflow menu.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get bookSourceListMoreActions;

  /// Opens the group management dialog.
  ///
  /// In en, this message translates to:
  /// **'Manage groups'**
  String get bookSourceListGroupManage;

  /// Group management action: rename a group everywhere.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get bookSourceListGroupRename;

  /// Group management action: remove the group from every source.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get bookSourceListGroupDelete;

  /// Confirms deleting a group everywhere.
  ///
  /// In en, this message translates to:
  /// **'Every source leaves “{group}”; the sources themselves stay.'**
  String bookSourceListGroupDeleteBody(String group);

  /// Batch action: takes the selection out of one group.
  ///
  /// In en, this message translates to:
  /// **'Remove from “{group}”'**
  String bookSourceListGroupRemoveFrom(String group);

  /// Row menu: runs the check on this one source.
  ///
  /// In en, this message translates to:
  /// **'Check this source'**
  String get bookSourceRowCheck;

  /// Row menu: opens the source's login page in the visible WebView.
  ///
  /// In en, this message translates to:
  /// **'Sign in / pass check'**
  String get bookSourceRowSignIn;

  /// Snackbar after the login / verification page finished.
  ///
  /// In en, this message translates to:
  /// **'The site\'s cookies are saved; the source can be checked again.'**
  String get bookSourceSignInDone;

  /// Snackbar when the login page failed for a reason other than the user closing it.
  ///
  /// In en, this message translates to:
  /// **'The sign-in / verification did not finish.'**
  String get bookSourceSignInFailed;

  /// Snackbar when the platform cannot show a verification page.
  ///
  /// In en, this message translates to:
  /// **'This platform has no WebView; finish the check in the system browser first.'**
  String get bookSourceSignInUnsupported;

  /// Row menu: opens the editor.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get bookSourceRowEdit;

  /// Row menu: copies / saves the source JSON.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get bookSourceRowExport;

  /// Snack bar after a single check that found nothing wrong.
  ///
  /// In en, this message translates to:
  /// **'Check passed'**
  String get bookSourceCheckPassed;

  /// Snack bar after a single check, naming the failure groups.
  ///
  /// In en, this message translates to:
  /// **'Check found: {groups}'**
  String bookSourceCheckFound(String groups);

  /// Snack bar after copying one source.
  ///
  /// In en, this message translates to:
  /// **'Source JSON copied'**
  String get bookSourceExportCopied;

  /// Snack bar after saving one source to a file.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get bookSourceExportSaved;

  /// Snack bar when the export fails.
  ///
  /// In en, this message translates to:
  /// **'Could not export this source'**
  String get bookSourceExportFailed;

  /// Editor page title.
  ///
  /// In en, this message translates to:
  /// **'Edit source'**
  String get bookSourceEditTitle;

  /// Snack bar after saving an edit.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get bookSourceEditSaved;

  /// Editor: validation failed.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted fields first'**
  String get bookSourceEditInvalidFields;

  /// Editor: the new identity already exists.
  ///
  /// In en, this message translates to:
  /// **'Another source already has exactly these rules'**
  String get bookSourceEditIdentityConflict;

  /// Editor hint when the URL differs from the stored one.
  ///
  /// In en, this message translates to:
  /// **'Changing the URL is like switching source: the shelf keeps the old one.'**
  String get bookSourceEditUrlHint;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get bookSourceFieldName;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Source URL'**
  String get bookSourceFieldUrl;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get bookSourceFieldGroup;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get bookSourceFieldType;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get bookSourceFieldWeight;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Header (JSON)'**
  String get bookSourceFieldHeader;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Search rule'**
  String get bookSourceFieldSearchRule;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Book info rule'**
  String get bookSourceFieldBookInfoRule;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Chapters rule'**
  String get bookSourceFieldTocRule;

  /// Editor field label.
  ///
  /// In en, this message translates to:
  /// **'Content rule'**
  String get bookSourceFieldContentRule;

  /// Generic save action.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Snack bar shown while a single-source check runs.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get bookSourceRowCheckRunning;

  /// Reader setting: which font family the body uses.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get readerFontFamily;

  /// Font family option: the app theme’s own font.
  ///
  /// In en, this message translates to:
  /// **'Theme default'**
  String get readerFontFamilyTheme;

  /// Font family option: serif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get readerFontFamilySerif;

  /// Font family option: sans-serif.
  ///
  /// In en, this message translates to:
  /// **'Sans-serif'**
  String get readerFontFamilySans;

  /// Font family option: monospace.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get readerFontFamilyMono;

  /// Reader setting: space between paragraphs.
  ///
  /// In en, this message translates to:
  /// **'Paragraph spacing'**
  String get readerParagraphSpacing;

  /// Reader setting: first-line indent.
  ///
  /// In en, this message translates to:
  /// **'First-line indent'**
  String get readerFirstLineIndent;

  /// Reader setting: page margin preset.
  ///
  /// In en, this message translates to:
  /// **'Page margin'**
  String get readerPagePadding;

  /// Page margin preset: narrow.
  ///
  /// In en, this message translates to:
  /// **'Narrow'**
  String get readerPaddingNarrow;

  /// Page margin preset: medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get readerPaddingMedium;

  /// Page margin preset: wide.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get readerPaddingWide;

  /// Reader UI text: readerChapterProgress.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total} chapters'**
  String readerChapterProgress(int current, int total);

  /// Reader UI text: readerChapterPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String readerChapterPercent(int percent);

  /// Reader UI text: readerChangeSource.
  ///
  /// In en, this message translates to:
  /// **'Change source'**
  String get readerChangeSource;

  /// Reader UI text: readerBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get readerBrightness;

  /// Reader UI text: readerTocSort.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get readerTocSort;

  /// Reader UI text: readerTocSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search chapters'**
  String get readerTocSearchHint;

  /// Reader UI text: readerSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Change source'**
  String get readerSourceTitle;

  /// Reader UI text: readerSourceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No other source has this book.'**
  String get readerSourceEmpty;

  /// Reader UI text: readerSourceSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching other sources…'**
  String get readerSourceSearching;

  /// Reader UI text: readerSourceChapters.
  ///
  /// In en, this message translates to:
  /// **'{count} chapters'**
  String readerSourceChapters(int count);

  /// Reader UI text: readerSourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch source'**
  String get readerSourceFailed;

  /// Reader UI text: readerSourceAligned.
  ///
  /// In en, this message translates to:
  /// **'Aligned to: {chapter}'**
  String readerSourceAligned(String chapter);

  /// Action that starts reading the chapter aloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get readerTtsAction;

  /// Title of the read-aloud sheet.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get readerTtsTitle;

  /// Button that starts reading the chapter aloud.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get readerTtsStart;

  /// Button that pauses speech.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get readerTtsPause;

  /// Button that resumes paused speech.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get readerTtsResume;

  /// Button that stops speech.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get readerTtsStop;

  /// Label of the speech rate slider.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get readerTtsRate;

  /// Label of the speech pitch slider.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get readerTtsPitch;

  /// Label of the system voice picker.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get readerTtsVoice;

  /// Voice picker entry: display name and locale.
  ///
  /// In en, this message translates to:
  /// **'{name} ({locale})'**
  String readerTtsVoiceLabel(String name, String locale);

  /// Voice picker entry that keeps the platform default voice.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get readerTtsSystemVoice;

  /// Switch that keeps speech running when the reader is closed.
  ///
  /// In en, this message translates to:
  /// **'Keep reading after leaving the reader'**
  String get readerTtsKeepOnExit;

  /// Shown when the TTS engine fails.
  ///
  /// In en, this message translates to:
  /// **'The system speech engine could not read this chapter.'**
  String get readerTtsFailed;

  /// Shown when an audio track cannot be loaded or played.
  ///
  /// In en, this message translates to:
  /// **'This track could not be played.'**
  String get readerAudioFailed;

  /// Action that starts audio playback.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get readerAudioPlay;

  /// Action that pauses audio playback.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get readerAudioPause;

  /// Action that restarts a finished track.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get readerAudioReplay;

  /// Label of the playback speed choices.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get readerAudioSpeed;

  /// Playback speed label; the placeholder already contains the multiplier.
  ///
  /// In en, this message translates to:
  /// **'{speed}×'**
  String readerAudioSpeedValue(String speed);

  /// Part indicator when an audio chapter has several tracks.
  ///
  /// In en, this message translates to:
  /// **'Part {index} of {total}'**
  String readerAudioTrackCount(int index, int total);

  /// Settings section heading for network behaviour.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsNetwork;

  /// Switch that opts into http:// for pages and media.
  ///
  /// In en, this message translates to:
  /// **'Allow plaintext HTTP'**
  String get settingsPlainHttp;

  /// Explanation under the plaintext-HTTP switch.
  ///
  /// In en, this message translates to:
  /// **'Some book sources and audio streams only provide http:// addresses. Page requests follow this switch too.'**
  String get settingsPlainHttpHint;

  /// Shown when an audio track is http and the user has not opted in.
  ///
  /// In en, this message translates to:
  /// **'This track uses plaintext HTTP. Turn on “Allow plaintext HTTP” in settings to play it.'**
  String get readerAudioPlainHttp;

  /// No description provided for @bookmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarkTitle;

  /// No description provided for @bookmarkEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet. Tap the bookmark button in the reader toolbar to mark your place.'**
  String get bookmarkEmpty;

  /// No description provided for @bookmarkLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks could not be loaded.'**
  String get bookmarkLoadFailed;

  /// No description provided for @bookmarkAdd.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get bookmarkAdd;

  /// No description provided for @bookmarkRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get bookmarkRemove;

  /// No description provided for @bookmarkAdded.
  ///
  /// In en, this message translates to:
  /// **'Bookmark added'**
  String get bookmarkAdded;

  /// No description provided for @bookmarkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed'**
  String get bookmarkRemoved;

  /// No description provided for @bookmarkFailed.
  ///
  /// In en, this message translates to:
  /// **'The bookmark could not be saved.'**
  String get bookmarkFailed;

  /// No description provided for @bookmarkDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark'**
  String get bookmarkDeleteAction;

  /// No description provided for @bookSourceReadingRecords.
  ///
  /// In en, this message translates to:
  /// **'Reading records'**
  String get bookSourceReadingRecords;

  /// No description provided for @readingRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading records'**
  String get readingRecordsTitle;

  /// No description provided for @readingRecordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reading records yet. Sessions shorter than a minute are not recorded.'**
  String get readingRecordsEmpty;

  /// No description provided for @readingRecordsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Reading records could not be loaded.'**
  String get readingRecordsLoadFailed;

  /// No description provided for @bookReadingRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading records · {book}'**
  String bookReadingRecordsTitle(String book);

  /// No description provided for @bookReadingRecordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'This book has no reading records yet.'**
  String get bookReadingRecordsEmpty;

  /// No description provided for @readingRecordMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String readingRecordMinutes(int minutes);

  /// No description provided for @readingRecordHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String readingRecordHours(int hours);

  /// No description provided for @readingRecordHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String readingRecordHoursMinutes(int hours, int minutes);

  /// No description provided for @myBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get myBookmarks;

  /// No description provided for @myBookmarksBody.
  ///
  /// In en, this message translates to:
  /// **'Every position you marked'**
  String get myBookmarksBody;

  /// No description provided for @myReadingRecords.
  ///
  /// In en, this message translates to:
  /// **'Reading records'**
  String get myReadingRecords;

  /// No description provided for @myReadingRecordsBody.
  ///
  /// In en, this message translates to:
  /// **'What you read, by day'**
  String get myReadingRecordsBody;

  /// No description provided for @shelfManageGroups.
  ///
  /// In en, this message translates to:
  /// **'Manage groups'**
  String get shelfManageGroups;

  /// No description provided for @shelfGroupAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get shelfGroupAll;

  /// No description provided for @shelfGroupUngrouped.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped'**
  String get shelfGroupUngrouped;

  /// No description provided for @shelfGroupEmpty.
  ///
  /// In en, this message translates to:
  /// **'No books in this group yet.'**
  String get shelfGroupEmpty;

  /// No description provided for @shelfGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get shelfGroupsTitle;

  /// No description provided for @shelfGroupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No groups yet. Create one with the button below.'**
  String get shelfGroupsEmpty;

  /// No description provided for @shelfGroupCreate.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get shelfGroupCreate;

  /// No description provided for @shelfGroupCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get shelfGroupCreateAction;

  /// No description provided for @shelfGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get shelfGroupNameHint;

  /// No description provided for @shelfGroupRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get shelfGroupRename;

  /// No description provided for @shelfGroupRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get shelfGroupRenameTitle;

  /// No description provided for @shelfGroupDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get shelfGroupDelete;

  /// No description provided for @shelfGroupDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get shelfGroupDeleteTitle;

  /// No description provided for @shelfGroupDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The books go back to ungrouped and are not deleted.'**
  String get shelfGroupDeleteBody;

  /// No description provided for @shelfGroupNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A group with this name already exists.'**
  String get shelfGroupNameTaken;

  /// No description provided for @shelfSelectionExit.
  ///
  /// In en, this message translates to:
  /// **'Exit selection'**
  String get shelfSelectionExit;

  /// No description provided for @shelfSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String shelfSelectionCount(int count);

  /// No description provided for @shelfSelectionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get shelfSelectionClear;

  /// No description provided for @shelfSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get shelfSelectAll;

  /// No description provided for @shelfBatchAction.
  ///
  /// In en, this message translates to:
  /// **'Batch actions'**
  String get shelfBatchAction;

  /// No description provided for @shelfBatchGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to group'**
  String get shelfBatchGroup;

  /// No description provided for @bookSourceShelfGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to group'**
  String get bookSourceShelfGroup;

  /// No description provided for @bookSourceShelfGroupHint.
  ///
  /// In en, this message translates to:
  /// **'Add the book to the shelf before grouping it.'**
  String get bookSourceShelfGroupHint;

  /// No description provided for @bookSourceChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Change cover'**
  String get bookSourceChangeCover;

  /// No description provided for @bookSourceResetCover.
  ///
  /// In en, this message translates to:
  /// **'Reset cover'**
  String get bookSourceResetCover;

  /// No description provided for @bookSourceBookCache.
  ///
  /// In en, this message translates to:
  /// **'Book cache'**
  String get bookSourceBookCache;

  /// No description provided for @bookSourceBookCacheCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chapters cached'**
  String bookSourceBookCacheCount(int count);

  /// No description provided for @bookSourceBookCacheClear.
  ///
  /// In en, this message translates to:
  /// **'Clear this book\'s cache'**
  String get bookSourceBookCacheClear;

  /// No description provided for @bookSourceBookCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared {count} cached items'**
  String bookSourceBookCacheCleared(int count);

  /// No description provided for @bookSourceBookCacheFailed.
  ///
  /// In en, this message translates to:
  /// **'The cache action failed.'**
  String get bookSourceBookCacheFailed;

  /// No description provided for @sourceVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} · {source}'**
  String sourceVerificationTitle(String title, String source);

  /// No description provided for @sourceVerificationDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sourceVerificationDone;

  /// No description provided for @sourceVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification was not completed.'**
  String get sourceVerificationFailed;

  /// No description provided for @sourceCaptchaTitle.
  ///
  /// In en, this message translates to:
  /// **'Captcha · {source}'**
  String sourceCaptchaTitle(String source);

  /// No description provided for @sourceCaptchaImage.
  ///
  /// In en, this message translates to:
  /// **'Captcha image'**
  String get sourceCaptchaImage;

  /// No description provided for @sourceCaptchaHint.
  ///
  /// In en, this message translates to:
  /// **'Type the characters in the image'**
  String get sourceCaptchaHint;

  /// No description provided for @sourceCaptchaConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get sourceCaptchaConfirm;

  /// No description provided for @failureLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'This source needs a sign-in or a fresh human check; open the source and finish it first.'**
  String get failureLoginRequired;

  /// No description provided for @mySectionRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get mySectionRules;

  /// No description provided for @rulesReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace & clean'**
  String get rulesReplaceTitle;

  /// No description provided for @rulesTocTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapter rules'**
  String get rulesTocTitle;

  /// No description provided for @rulesDictTitle.
  ///
  /// In en, this message translates to:
  /// **'Dictionaries'**
  String get rulesDictTitle;

  /// No description provided for @rulesHighlightTitle.
  ///
  /// In en, this message translates to:
  /// **'Highlight tags'**
  String get rulesHighlightTitle;

  /// No description provided for @rulesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get rulesAdd;

  /// No description provided for @rulesEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get rulesEditTitle;

  /// No description provided for @rulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rules yet'**
  String get rulesEmpty;

  /// No description provided for @rulesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The rules could not be loaded.'**
  String get rulesLoadFailed;

  /// No description provided for @rulesGone.
  ///
  /// In en, this message translates to:
  /// **'This rule no longer exists.'**
  String get rulesGone;

  /// No description provided for @rulesBroken.
  ///
  /// In en, this message translates to:
  /// **'Unreadable rule'**
  String get rulesBroken;

  /// No description provided for @rulesBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get rulesBuiltIn;

  /// No description provided for @rulesBrokenNotice.
  ///
  /// In en, this message translates to:
  /// **'This rule\'s stored content cannot be read. It is shown below; saving replaces it.'**
  String get rulesBrokenNotice;

  /// No description provided for @rulesReorderHandle.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get rulesReorderHandle;

  /// No description provided for @rulesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get rulesNameLabel;

  /// No description provided for @rulesPatternLabel.
  ///
  /// In en, this message translates to:
  /// **'Find (regular expression or text)'**
  String get rulesPatternLabel;

  /// No description provided for @rulesReplacementLabel.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get rulesReplacementLabel;

  /// No description provided for @rulesIsRegexLabel.
  ///
  /// In en, this message translates to:
  /// **'Use a regular expression'**
  String get rulesIsRegexLabel;

  /// No description provided for @rulesRuleLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter title rule'**
  String get rulesRuleLabel;

  /// No description provided for @rulesSerialNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial number (optional)'**
  String get rulesSerialNumberLabel;

  /// No description provided for @rulesUrlRuleLabel.
  ///
  /// In en, this message translates to:
  /// **'Lookup address'**
  String get rulesUrlRuleLabel;

  /// No description provided for @rulesShowRuleLabel.
  ///
  /// In en, this message translates to:
  /// **'Extract rule'**
  String get rulesShowRuleLabel;

  /// No description provided for @rulesColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Colour, #AARRGGBB (optional)'**
  String get rulesColorLabel;

  /// No description provided for @rulesGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group (optional)'**
  String get rulesGroupLabel;

  /// No description provided for @rulesEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get rulesEnabledLabel;

  /// No description provided for @rulesRequired.
  ///
  /// In en, this message translates to:
  /// **'Required.'**
  String get rulesRequired;

  /// No description provided for @rulesInvalidRegex.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid regular expression.'**
  String get rulesInvalidRegex;

  /// No description provided for @rulesInvalidColor.
  ///
  /// In en, this message translates to:
  /// **'Use #RRGGBB or #AARRGGBB.'**
  String get rulesInvalidColor;

  /// No description provided for @readerSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Search in book'**
  String get readerSearchAction;

  /// No description provided for @readerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search this book'**
  String get readerSearchHint;

  /// No description provided for @readerSearchStart.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get readerSearchStart;

  /// No description provided for @readerSearchStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get readerSearchStop;

  /// No description provided for @readerSearchProgress.
  ///
  /// In en, this message translates to:
  /// **'Searched {scanned} of {total} chapters'**
  String readerSearchProgress(int scanned, int total);

  /// No description provided for @readerSearchStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped after {scanned} of {total} chapters.'**
  String readerSearchStopped(int scanned, int total);

  /// No description provided for @readerSearchBudgetSpent.
  ///
  /// In en, this message translates to:
  /// **'Time is up: stopped after {scanned} of {total} chapters.'**
  String readerSearchBudgetSpent(int scanned, int total);

  /// No description provided for @readerSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found.'**
  String get readerSearchEmpty;

  /// No description provided for @readerSearchFailedChapters.
  ///
  /// In en, this message translates to:
  /// **'{count} chapters could not be read.'**
  String readerSearchFailedChapters(int count);

  /// No description provided for @readerSearchUntitledChapter.
  ///
  /// In en, this message translates to:
  /// **'Untitled chapter'**
  String get readerSearchUntitledChapter;

  /// No description provided for @rulesImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import rules'**
  String get rulesImportTitle;

  /// No description provided for @rulesImportTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Rules JSON'**
  String get rulesImportTextLabel;

  /// No description provided for @rulesImportTextHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the contents of a 净化规则 JSON file'**
  String get rulesImportTextHint;

  /// No description provided for @rulesImportUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Or a URL'**
  String get rulesImportUrlLabel;

  /// No description provided for @rulesImportUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://…/replaceRules.json'**
  String get rulesImportUrlHint;

  /// No description provided for @rulesImportFileAction.
  ///
  /// In en, this message translates to:
  /// **'Choose a JSON file'**
  String get rulesImportFileAction;

  /// No description provided for @rulesImportSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Import all of them'**
  String get rulesImportSelectAll;

  /// No description provided for @rulesImportSelected.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {usable} selected'**
  String rulesImportSelected(int selected, int usable);

  /// No description provided for @rulesImportCommit.
  ///
  /// In en, this message translates to:
  /// **'Import selected ({count})'**
  String rulesImportCommit(int count);

  /// No description provided for @rulesImportSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Imported {created} new rules and updated {updated}.'**
  String rulesImportSucceeded(int created, int updated);

  /// No description provided for @rulesImportSucceededWithSkipped.
  ///
  /// In en, this message translates to:
  /// **'Imported {created} new rules and updated {updated}; {skipped} entries were skipped as unreadable.'**
  String rulesImportSucceededWithSkipped(int created, int updated, int skipped);

  /// No description provided for @rulesImportUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled rule'**
  String get rulesImportUntitled;

  /// No description provided for @rulesImportUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get rulesImportUpdate;

  /// No description provided for @rulesImportProblemFormat.
  ///
  /// In en, this message translates to:
  /// **'not a rule object'**
  String get rulesImportProblemFormat;

  /// No description provided for @rulesImportProblemMissingPattern.
  ///
  /// In en, this message translates to:
  /// **'missing pattern'**
  String get rulesImportProblemMissingPattern;

  /// No description provided for @rulesExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get rulesExportAction;

  /// No description provided for @rulesExportEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no rules to export.'**
  String get rulesExportEmpty;

  /// No description provided for @rulesExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} rules.'**
  String rulesExportSaved(int count);

  /// No description provided for @rulesExportSavedWithSkipped.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} rules; {skipped} unreadable rules were left out.'**
  String rulesExportSavedWithSkipped(int count, int skipped);

  /// No description provided for @rulesExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the rules.'**
  String get rulesExportFailed;

  /// No description provided for @rulesScopeBoth.
  ///
  /// In en, this message translates to:
  /// **'title + body'**
  String get rulesScopeBoth;

  /// No description provided for @rulesScopeContent.
  ///
  /// In en, this message translates to:
  /// **'body only'**
  String get rulesScopeContent;

  /// No description provided for @rulesScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'title only'**
  String get rulesScopeTitle;

  /// No description provided for @rulesScopeNone.
  ///
  /// In en, this message translates to:
  /// **'not applied'**
  String get rulesScopeNone;

  /// No description provided for @bookSourceExportAll.
  ///
  /// In en, this message translates to:
  /// **'Export all'**
  String get bookSourceExportAll;

  /// No description provided for @bookSourceExportSelected.
  ///
  /// In en, this message translates to:
  /// **'Export selected ({count})'**
  String bookSourceExportSelected(int count);

  /// No description provided for @bookSourceExportAllSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} book sources.'**
  String bookSourceExportAllSaved(int count);

  /// No description provided for @bookSourceExportEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no book sources to export.'**
  String get bookSourceExportEmpty;

  /// No description provided for @rulesListMenu.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get rulesListMenu;

  /// No description provided for @mySectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get mySectionData;

  /// No description provided for @cacheManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Cached chapters'**
  String get cacheManageTitle;

  /// No description provided for @cacheManageMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get cacheManageMore;

  /// No description provided for @cacheManageTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} cached chapters in total'**
  String cacheManageTotal(int count);

  /// No description provided for @cacheManageSourceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chapters'**
  String cacheManageSourceCount(int count);

  /// No description provided for @cacheManageClearSource.
  ///
  /// In en, this message translates to:
  /// **'Clear this source'**
  String get cacheManageClearSource;

  /// No description provided for @cacheManageClearExpired.
  ///
  /// In en, this message translates to:
  /// **'Clear expired entries'**
  String get cacheManageClearExpired;

  /// No description provided for @cacheManageClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear the whole cache'**
  String get cacheManageClearAll;

  /// No description provided for @cacheManageClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the whole cache?'**
  String get cacheManageClearAllTitle;

  /// No description provided for @cacheManageClearAllBody.
  ///
  /// In en, this message translates to:
  /// **'Cached chapters and probe results are downloaded again when needed.'**
  String get cacheManageClearAllBody;

  /// No description provided for @cacheManageEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is cached.'**
  String get cacheManageEmpty;

  /// No description provided for @cacheManageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The cache could not be read.'**
  String get cacheManageLoadFailed;

  /// No description provided for @myCookies.
  ///
  /// In en, this message translates to:
  /// **'Cookies'**
  String get myCookies;

  /// No description provided for @myCookiesBody.
  ///
  /// In en, this message translates to:
  /// **'What sites stored to keep you signed in'**
  String get myCookiesBody;

  /// No description provided for @cookieManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Cookies'**
  String get cookieManageTitle;

  /// No description provided for @cookieManageMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get cookieManageMore;

  /// No description provided for @cookieManageSession.
  ///
  /// In en, this message translates to:
  /// **'Until the app closes'**
  String get cookieManageSession;

  /// No description provided for @cookieManageExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires {moment}'**
  String cookieManageExpiresAt(String moment);

  /// No description provided for @cookieManageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete this cookie'**
  String get cookieManageDelete;

  /// No description provided for @cookieManageClearDomain.
  ///
  /// In en, this message translates to:
  /// **'Clear this domain'**
  String get cookieManageClearDomain;

  /// No description provided for @cookieManageClearExpired.
  ///
  /// In en, this message translates to:
  /// **'Clear expired cookies'**
  String get cookieManageClearExpired;

  /// No description provided for @cookieManageClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all cookies'**
  String get cookieManageClearAll;

  /// No description provided for @cookieManageClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all cookies?'**
  String get cookieManageClearAllTitle;

  /// No description provided for @cookieManageClearAllBody.
  ///
  /// In en, this message translates to:
  /// **'Every site will ask you to sign in again.'**
  String get cookieManageClearAllBody;

  /// No description provided for @cookieManageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cookies are stored.'**
  String get cookieManageEmpty;

  /// No description provided for @cookieManageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The cookies could not be read.'**
  String get cookieManageLoadFailed;

  /// No description provided for @bookSourceLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get bookSourceLoginTitle;

  /// No description provided for @bookSourceLoginLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The login form could not be read.'**
  String get bookSourceLoginLoadFailed;

  /// No description provided for @bookSourceLoginNoForm.
  ///
  /// In en, this message translates to:
  /// **'This source declares no login form.'**
  String get bookSourceLoginNoForm;

  /// No description provided for @bookSourceLoginWorking.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get bookSourceLoginWorking;

  /// No description provided for @bookSourceLoginDone.
  ///
  /// In en, this message translates to:
  /// **'Signed in. The source\'s own script reported success.'**
  String get bookSourceLoginDone;

  /// No description provided for @myBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get myBackup;

  /// No description provided for @myBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Pack everything into one zip, or restore from one'**
  String get myBackupBody;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get backupTitle;

  /// No description provided for @backupExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export a backup'**
  String get backupExportTitle;

  /// No description provided for @backupExportBody.
  ///
  /// In en, this message translates to:
  /// **'Book sources, shelf, groups, bookmarks, reading records, rules and settings, packed into one zip.'**
  String get backupExportBody;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get backupRestoreTitle;

  /// No description provided for @backupRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'See what the archive holds first, then merge it into this device.'**
  String get backupRestoreBody;

  /// No description provided for @backupIncludeSecretsHint.
  ///
  /// In en, this message translates to:
  /// **'The archive is a plain file and includes book-source login data. Keep it somewhere you trust.'**
  String get backupIncludeSecretsHint;

  /// No description provided for @backupWorkingExporting.
  ///
  /// In en, this message translates to:
  /// **'Packing…'**
  String get backupWorkingExporting;

  /// No description provided for @backupWorkingReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the archive…'**
  String get backupWorkingReading;

  /// No description provided for @backupWorkingRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get backupWorkingRestoring;

  /// No description provided for @backupPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'What the archive holds'**
  String get backupPreviewTitle;

  /// No description provided for @backupPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'This archive holds no rows.'**
  String get backupPreviewEmpty;

  /// No description provided for @backupConfirmRestore.
  ///
  /// In en, this message translates to:
  /// **'Merge into this device'**
  String get backupConfirmRestore;

  /// No description provided for @backupMergeHint.
  ///
  /// In en, this message translates to:
  /// **'Restoring only merges: anything this device has that the archive lacks stays as it is.'**
  String get backupMergeHint;

  /// No description provided for @backupTableBookSources.
  ///
  /// In en, this message translates to:
  /// **'Book sources'**
  String get backupTableBookSources;

  /// No description provided for @backupTableBooks.
  ///
  /// In en, this message translates to:
  /// **'Shelf'**
  String get backupTableBooks;

  /// No description provided for @backupTableReadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Reading progress'**
  String get backupTableReadingProgress;

  /// No description provided for @backupTableBookGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get backupTableBookGroups;

  /// No description provided for @backupTableBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get backupTableBookmarks;

  /// No description provided for @backupTableReadRecords.
  ///
  /// In en, this message translates to:
  /// **'Reading records'**
  String get backupTableReadRecords;

  /// No description provided for @backupTableRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get backupTableRules;

  /// No description provided for @backupExported.
  ///
  /// In en, this message translates to:
  /// **'Saved {fileName} ({count} rows).'**
  String backupExported(String fileName, int count);

  /// No description provided for @backupPreviewMeta.
  ///
  /// In en, this message translates to:
  /// **'Written {createdAt} by version {appVersion}.'**
  String backupPreviewMeta(String createdAt, String appVersion);

  /// No description provided for @backupPreviewPreferences.
  ///
  /// In en, this message translates to:
  /// **'{count} settings'**
  String backupPreviewPreferences(int count);

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Merged: {changed} rows written, {preferences} settings.'**
  String backupRestored(int changed, int preferences);

  /// No description provided for @backupAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get backupAutoTitle;

  /// No description provided for @backupAutoBody.
  ///
  /// In en, this message translates to:
  /// **'Backs up once a day at start-up when the last archive is older than a day.'**
  String get backupAutoBody;

  /// No description provided for @backupRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Backups to keep'**
  String get backupRetentionTitle;

  /// No description provided for @backupRetentionBody.
  ///
  /// In en, this message translates to:
  /// **'Older archives beyond this count are deleted; only files this app wrote are removed.'**
  String get backupRetentionBody;

  /// No description provided for @backupRetentionValue.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String backupRetentionValue(int count);

  /// No description provided for @backupLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup location'**
  String get backupLocationTitle;

  /// No description provided for @backupLocationPrivate.
  ///
  /// In en, this message translates to:
  /// **'App private folder'**
  String get backupLocationPrivate;

  /// No description provided for @backupLocationChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get backupLocationChoose;

  /// No description provided for @backupLocationReset.
  ///
  /// In en, this message translates to:
  /// **'Use the private folder'**
  String get backupLocationReset;

  /// No description provided for @backupLocationFallback.
  ///
  /// In en, this message translates to:
  /// **'The chosen folder is unavailable; archives go to the app\'s private folder for now.'**
  String get backupLocationFallback;

  /// No description provided for @backupPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPasswordTitle;

  /// No description provided for @backupPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'When set, whole archives are encrypted (AES-256); the password lives in the system key store.'**
  String get backupPasswordBody;

  /// No description provided for @backupPasswordChange.
  ///
  /// In en, this message translates to:
  /// **'Change the password'**
  String get backupPasswordChange;

  /// No description provided for @backupPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get backupPasswordSet;

  /// No description provided for @backupPasswordClear.
  ///
  /// In en, this message translates to:
  /// **'Remove the password'**
  String get backupPasswordClear;

  /// No description provided for @backupPasswordStored.
  ///
  /// In en, this message translates to:
  /// **'Set (archives are encrypted)'**
  String get backupPasswordStored;

  /// No description provided for @backupPasswordMissing.
  ///
  /// In en, this message translates to:
  /// **'Not set (archives stay unencrypted)'**
  String get backupPasswordMissing;

  /// No description provided for @backupPasswordStoreFailed.
  ///
  /// In en, this message translates to:
  /// **'The key store is unavailable, so the password was not stored: archives stay unencrypted.'**
  String get backupPasswordStoreFailed;

  /// No description provided for @backupSaveToLocation.
  ///
  /// In en, this message translates to:
  /// **'Save to the backup location'**
  String get backupSaveToLocation;

  /// No description provided for @backupSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get backupSaveAs;

  /// No description provided for @backupRestoreFromFile.
  ///
  /// In en, this message translates to:
  /// **'Restore from a file'**
  String get backupRestoreFromFile;

  /// No description provided for @backupSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String backupSavedTo(String path);

  /// No description provided for @backupRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud backups'**
  String get backupRemoteTitle;

  /// No description provided for @backupRemoteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No backup files on the server.'**
  String get backupRemoteEmpty;

  /// No description provided for @backupRemoteRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from the cloud'**
  String get backupRemoteRestore;

  /// No description provided for @backupRemoteDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the cloud backup'**
  String get backupRemoteDelete;

  /// No description provided for @backupCloudUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload the current backup'**
  String get backupCloudUpload;

  /// No description provided for @backupCloudRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh the cloud list'**
  String get backupCloudRefresh;

  /// No description provided for @backupWebDavTitle.
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get backupWebDavTitle;

  /// No description provided for @backupWebDavUrl.
  ///
  /// In en, this message translates to:
  /// **'URL (collection)'**
  String get backupWebDavUrl;

  /// No description provided for @backupWebDavUsername.
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get backupWebDavUsername;

  /// No description provided for @backupWebDavPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get backupWebDavPassword;

  /// No description provided for @backupWebDavSave.
  ///
  /// In en, this message translates to:
  /// **'Save the WebDAV configuration'**
  String get backupWebDavSave;

  /// No description provided for @backupWebDavNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'WebDAV is not configured yet.'**
  String get backupWebDavNotConfigured;

  /// No description provided for @backupPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'This archive is encrypted and needs its password.'**
  String get backupPasswordRequired;

  /// No description provided for @backupPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the backup password'**
  String get backupPasswordPrompt;

  /// No description provided for @backupPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'That password is wrong; try again.'**
  String get backupPasswordWrong;

  /// No description provided for @backupMergeMode.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get backupMergeMode;

  /// No description provided for @backupOverwriteMode.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get backupOverwriteMode;

  /// No description provided for @backupOverwriteWarning.
  ///
  /// In en, this message translates to:
  /// **'Overwriting clears this device\'s book sources, shelf, groups, bookmarks, reading records and rules first, then writes the archive; a safety copy is saved before it starts.'**
  String get backupOverwriteWarning;

  /// No description provided for @backupOverwriteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Overwrite this device'**
  String get backupOverwriteConfirm;

  /// No description provided for @backupSafetyCopy.
  ///
  /// In en, this message translates to:
  /// **'Safety copy saved first: {name}'**
  String backupSafetyCopy(String name);

  /// No description provided for @backupWorkSavingAs.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get backupWorkSavingAs;

  /// No description provided for @backupWorkUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get backupWorkUploading;

  /// No description provided for @backupWorkListingRemote.
  ///
  /// In en, this message translates to:
  /// **'Listing the cloud collection…'**
  String get backupWorkListingRemote;

  /// No description provided for @backupWorkDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get backupWorkDownloading;

  /// No description provided for @backupLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get backupLocalTitle;

  /// No description provided for @settingsSeedColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get settingsSeedColor;

  /// No description provided for @settingsSeedColorHint.
  ///
  /// In en, this message translates to:
  /// **'Dynamic colour wins when the platform has it; this decides the colours on devices that do not.'**
  String get settingsSeedColorHint;

  /// No description provided for @settingsSeedColorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsSeedColorDefault;

  /// No description provided for @settingsBackgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get settingsBackgroundImage;

  /// No description provided for @settingsBackgroundImageNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsBackgroundImageNone;

  /// No description provided for @settingsBackgroundImageChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose an image'**
  String get settingsBackgroundImageChoose;

  /// No description provided for @settingsBackgroundImageRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsBackgroundImageRemove;

  /// No description provided for @settingsBackgroundImageHint.
  ///
  /// In en, this message translates to:
  /// **'The image is copied into the app, so deleting the original is fine.'**
  String get settingsBackgroundImageHint;

  /// No description provided for @settingsBackgroundImageFailed.
  ///
  /// In en, this message translates to:
  /// **'The background image could not be saved; try again.'**
  String get settingsBackgroundImageFailed;

  /// No description provided for @externalLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Open this address?'**
  String get externalLinkTitle;

  /// No description provided for @externalLinkFrom.
  ///
  /// In en, this message translates to:
  /// **'{source} wants to open this address in your browser:'**
  String externalLinkFrom(Object source);

  /// No description provided for @externalLinkOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get externalLinkOpen;

  /// No description provided for @externalLinkCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get externalLinkCancel;

  /// Log verbosity setting (ADR-0082).
  ///
  /// In en, this message translates to:
  /// **'Log level'**
  String get settingsLogLevel;

  /// No description provided for @settingsLogLevelHint.
  ///
  /// In en, this message translates to:
  /// **'Records below this level are dropped. Applies immediately.'**
  String get settingsLogLevelHint;

  /// No description provided for @settingsLogDebug.
  ///
  /// In en, this message translates to:
  /// **'debug'**
  String get settingsLogDebug;

  /// No description provided for @settingsLogInfo.
  ///
  /// In en, this message translates to:
  /// **'info'**
  String get settingsLogInfo;

  /// No description provided for @settingsLogWarning.
  ///
  /// In en, this message translates to:
  /// **'warning'**
  String get settingsLogWarning;

  /// No description provided for @settingsLogError.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get settingsLogError;

  /// No description provided for @settingsLogOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get settingsLogOff;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsLogFiles.
  ///
  /// In en, this message translates to:
  /// **'Log files'**
  String get settingsLogFiles;

  /// No description provided for @settingsLogFilesBody.
  ///
  /// In en, this message translates to:
  /// **'Kept for 7 days, at most 20 MB in total.'**
  String get settingsLogFilesBody;

  /// No description provided for @logFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Log files'**
  String get logFilesTitle;

  /// No description provided for @logFilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log file yet.'**
  String get logFilesEmpty;

  /// No description provided for @logFilesClear.
  ///
  /// In en, this message translates to:
  /// **'Clear every log file'**
  String get logFilesClear;

  /// No description provided for @logFilesCleared.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} file(s).'**
  String logFilesCleared(int count);

  /// No description provided for @logFilesCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy the folder path'**
  String get logFilesCopyPath;

  /// No description provided for @logFilesCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied.'**
  String get logFilesCopied;

  /// No description provided for @logFilesTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {size}'**
  String logFilesTotal(String size);

  /// List entry that opens the system share sheet with all log files (ADR-0083).
  ///
  /// In en, this message translates to:
  /// **'Share every log file'**
  String get logFilesShareAll;

  /// Tooltip of the share button on one log file row.
  ///
  /// In en, this message translates to:
  /// **'Share this file'**
  String get logFilesShareFile;

  /// Explains why the log folder needs a share action on Android.
  ///
  /// In en, this message translates to:
  /// **'The folder is private to the app; sharing hands a copy to another app.'**
  String get logFilesShareBody;

  /// Snack bar shown when the system share sheet fails.
  ///
  /// In en, this message translates to:
  /// **'Could not share the log files.'**
  String get logFilesShareFailed;
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
