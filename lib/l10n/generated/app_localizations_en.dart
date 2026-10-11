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
      'No book source is selected yet. Importing book sources arrives in a later version.';

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
}
