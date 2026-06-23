import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:plant_disease_mobile/domain/prediction.dart';

class ScanHistoryItem {
  final DateTime createdAt;
  final String imagePath; // local file path
  final Prediction prediction;

  const ScanHistoryItem({
    required this.createdAt,
    required this.imagePath,
    required this.prediction,
  });

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt.toIso8601String(),
        'imagePath': imagePath,
        'prediction': prediction.toJson(),
      };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) =>
      ScanHistoryItem(
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        imagePath: json['imagePath'] as String? ?? '',
        prediction:
            Prediction.fromJson(json['prediction'] as Map<String, dynamic>),
      );
}

/// Persistent scan history, stored locally on the device with
/// shared_preferences and scoped per signed-in user, so the history survives
/// app restarts and is kept separately for each account (NOT lost on logout).
class ScanHistoryStore {
  static final ScanHistoryStore instance = ScanHistoryStore._();
  ScanHistoryStore._();

  static const String _keyPrefix = 'scan_history_';

  List<ScanHistoryItem> _items = [];
  String _userKey = 'guest'; // current storage scope (user uid or "guest")

  List<ScanHistoryItem> get items => List.unmodifiable(_items);

  String _prefsKey(String userKey) => '$_keyPrefix$userKey';

  /// Switch to a user's history scope and load it from local storage.
  /// Call on app start and right after sign-in (pass the user's uid), or with
  /// "guest"/null for a signed-out session.
  Future<void> loadForUser(String? userId) async {
    _userKey = (userId == null || userId.isEmpty) ? 'guest' : userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(_userKey));
      if (raw == null || raw.isEmpty) {
        _items = [];
        return;
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items = decoded
          .map((e) => ScanHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _items = []; // corrupt/old data — start clean
    }
  }

  void add(ScanHistoryItem item) {
    _items.insert(0, item);
    _persist();
  }

  void clear() {
    _items.clear();
    _persist();
  }

  /// On sign-out: clears only the in-memory list (so the next user doesn't see
  /// the previous user's scans) WITHOUT deleting what's saved on disk — it
  /// comes back when that user signs in again.
  void detach() {
    _items = [];
    _userKey = 'guest';
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey(_userKey), raw);
    } catch (_) {
      // ignore persistence errors — history still works in-memory this session
    }
  }
}
