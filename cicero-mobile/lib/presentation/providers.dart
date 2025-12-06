import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cicero_api_client.dart';

// --- CORE SERVICES ---

// The only API client we need now. It talks to your Python Backend.
final ciceroApiClientProvider = Provider<CiceroApiClient>((ref) {
  return CiceroApiClient();
});

// --- STATE MANAGEMENT ---

// Stores the user's selected state (e.g., "CA", "TX")
final selectedStateProvider = StateProvider<String>((ref) => 'CA');

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
