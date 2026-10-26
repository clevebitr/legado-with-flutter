// coverage:ignore-file
import 'package:drift/drift.dart';

/// One persisted cookie.
///
/// Matches the HTTP client's cookie shape, keeping logins across restarts.
@DataClassName('CookieRow')
@TableIndex(name: 'cookies_domain', columns: {#domain})
class Cookies extends Table {
  /// Synthetic primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Cookie domain (no leading dot), as RFC 6265 normalizes it.
  TextColumn get domain => text()();

  /// Cookie path, `/` when the server said nothing.
  TextColumn get path => text()();

  /// Cookie name.
  TextColumn get name => text()();

  /// Cookie value.
  TextColumn get value => text()();

  /// Whether the cookie may only travel over HTTPS.
  BoolColumn get isSecure => boolean().withDefault(const Constant(false))();

  /// When the cookie stops being valid, or `null` for a session cookie.
  DateTimeColumn get expiresAt => dateTime().nullable()();

  /// When the row was written; a diagnostic column, not a cookie attribute.
  DateTimeColumn get createdAt => dateTime()();

  /// One cookie per (domain, path, name).
  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{domain, path, name},
  ];
}
