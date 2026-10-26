import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preference_store_provider.g.dart';

/// Provides the key-value store for lightweight switches.
///
/// `keepAlive` because opening the platform store is the expensive part.
@Riverpod(keepAlive: true)
Future<PreferenceStore> preferenceStore(Ref ref) async =>
    PreferenceStore(await SharedPreferences.getInstance());
