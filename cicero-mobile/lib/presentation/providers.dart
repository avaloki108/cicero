import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/cicero_api_client.dart';

String _sanitizeBaseUrl(String url) {
  var cleaned = url.trim();
  if (cleaned.isEmpty) return CiceroApiClient.defaultBaseUrl;
  if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
    cleaned = 'http://$cleaned';
  }
  try {
    final uri = Uri.parse(cleaned);
    final port = uri.hasPort && uri.port == 8013 ? 8000 : (uri.hasPort ? uri.port : null);
    final normalized = uri.replace(port: port == 0 ? null : port);
    cleaned = normalized.toString();
  } catch (_) {
    // keep cleaned as-is if parse fails
  }
  return cleaned.endsWith('/')
      ? cleaned.substring(0, cleaned.length - 1)
      : cleaned;
}

// --- CORE SERVICES ---

// The only API client we need now. It talks to your Python Backend.
final ciceroApiClientProvider = Provider<CiceroApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return CiceroApiClient(baseUrl: baseUrl);
});

// --- STATE MANAGEMENT ---

class SelectedStateNotifier extends StateNotifier<String> {
  SelectedStateNotifier(this._box, String initialState) : super(initialState);

  final Box<dynamic> _box;

  void setStateAbbr(String abbr) {
    state = abbr;
    _box.put('state_abbr', abbr);
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._box, ThemeMode initialMode) : super(initialMode);

  final Box<dynamic> _box;

  void setMode(ThemeMode mode) {
    state = mode;
    _box.put('theme_mode', mode.name);
  }
}

class ApiBaseUrlNotifier extends StateNotifier<String> {
  ApiBaseUrlNotifier(this._box, String initialUrl) : super(initialUrl);

  final Box<dynamic> _box;

  void setBaseUrl(String url) {
    final cleaned = _sanitizeBaseUrl(url);
    _box.put('api_base_url', cleaned);
    state = cleaned;
  }
}

final selectedStateProvider =
    StateNotifierProvider<SelectedStateNotifier, String>((ref) {
  final box = Hive.box('cicero_settings');
  final initial = box.get('state_abbr', defaultValue: 'CA') as String;
  return SelectedStateNotifier(box, initial);
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final box = Hive.box('cicero_settings');
  final stored = (box.get('theme_mode') as String?) ?? 'system';
  final mode = {
    'light': ThemeMode.light,
    'dark': ThemeMode.dark,
  }[stored] ?? ThemeMode.system;
  return ThemeModeNotifier(box, mode);
});

final apiBaseUrlProvider =
    StateNotifierProvider<ApiBaseUrlNotifier, String>((ref) {
  final box = Hive.box('cicero_settings');
  final stored = (box.get('api_base_url') as String?) ??
      CiceroApiClient.defaultBaseUrl;
  final sanitized = _sanitizeBaseUrl(stored);
  // If we changed the value (e.g., migrating 8013 -> 8000), persist it.
  if (sanitized != stored) {
    box.put('api_base_url', sanitized);
  }
  return ApiBaseUrlNotifier(box, sanitized);
});

final tabIndexProvider = StateProvider<int>((ref) => 0);

// Tracks the number of successful chats (useful for viral prompts later)
final chatCounterProvider = StateProvider<int>((ref) => 0);

// --- HELPER CONSTANTS ---

const stateNameToAbbr = {
  'California': 'CA',
  'Colorado': 'CO',
  'New York': 'NY',
  'Texas': 'TX',
  'Florida': 'FL',
  // Add more as needed...
};

const abbrToStateName = {
  'CA': 'California',
  'CO': 'Colorado',
  'NY': 'New York',
  'TX': 'Texas',
  'FL': 'Florida',
};
