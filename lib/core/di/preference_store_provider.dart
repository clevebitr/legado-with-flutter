import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preference_store_provider.g.dart';

/// Provides the key-value store for light switches (C-NET-9).
///
/// `keepAlive` because opening the platform store is the expensive part and every settings read
/// goes through it; tests inject a fake by overriding this provider
/// (`ProviderScope(overrides: …)`, `docs/dev/testing.md` §4).
@Riverpod(keepAlive: true)
Future<PreferenceStore> preferenceStore(Ref ref) async =>
    PreferenceStore(await SharedPreferences.getInstance());
