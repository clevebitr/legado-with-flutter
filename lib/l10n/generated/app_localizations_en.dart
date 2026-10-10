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
  String get failureUnsupportedRule =>
      'This book source uses a rule type that is not supported yet.';
}
