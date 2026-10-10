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

  /// User-facing message for ParseFailureKind.unsupportedRule.
  ///
  /// In en, this message translates to:
  /// **'This book source uses a rule type that is not supported yet.'**
  String get failureUnsupportedRule;
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
