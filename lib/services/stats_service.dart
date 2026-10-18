import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LifetimeStats {
  const LifetimeStats({
    required this.totalGamesPlayed,
    required this.totalGamesTwinned,
    required this.totalRoundsPlayed,
    required this.fastestConvergenceRounds,
    required this.topBridgeWords,
  });

  final int totalGamesPlayed;
  final int totalGamesTwinned;
  final int totalRoundsPlayed;
  final int? fastestConvergenceRounds;
  final List<MapEntry<String, int>> topBridgeWords;

  double get convergenceRate =>
      totalGamesPlayed > 0 ? (totalGamesTwinned / totalGamesPlayed) : 0.0;

  double get averageRounds =>
      totalGamesPlayed > 0 ? (totalRoundsPlayed / totalGamesPlayed) : 0.0;
}

/// Manages local persistent lifetime statistics and conceptual bridge words.
class StatsService extends ChangeNotifier {
  StatsService._();
  static final StatsService instance = StatsService._();

  static const _kGamesPlayed = 'stats_games_played';
  static const _kGamesTwinned = 'stats_games_twinned';
  static const _kRoundsPlayed = 'stats_rounds_played';
  static const _kFastestRounds = 'stats_fastest_rounds';
  static const _kBridgeWords = 'stats_bridge_words';

  LifetimeStats? _cached;
  LifetimeStats? get cached => _cached;

  Future<LifetimeStats> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final played = prefs.getInt(_kGamesPlayed) ?? 0;
    final twinned = prefs.getInt(_kGamesTwinned) ?? 0;
    final rounds = prefs.getInt(_kRoundsPlayed) ?? 0;
    final fastest = prefs.getInt(_kFastestRounds);

    final rawJson = prefs.getString(_kBridgeWords);
    final map = <String, int>{};
    if (rawJson != null) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final count = (entry.value as num?)?.toInt() ?? 0;
            if (count > 0) {
              map[entry.key.toString()] = count;
            }
          }
        }
      } catch (_) {}
    }

    final sortedWords = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final stats = LifetimeStats(
      totalGamesPlayed: played,
      totalGamesTwinned: twinned,
      totalRoundsPlayed: rounds,
      fastestConvergenceRounds: fastest,
      topBridgeWords: sortedWords.take(15).toList(growable: false),
    );
    _cached = stats;
    return stats;
  }

  Future<void> reload() async {
    await getStats();
    notifyListeners();
  }

  Future<void> recordRoundWord(String rawWord) async {
    final word = rawWord.trim().toLowerCase();
    if (word.length < 2) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_kBridgeWords);
      final map = <String, int>{};
      if (rawJson != null) {
        try {
          final decoded = jsonDecode(rawJson);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              map[entry.key.toString()] = (entry.value as num?)?.toInt() ?? 0;
            }
          }
        } catch (_) {}
      }

      map[word] = (map[word] ?? 0) + 1;
      await prefs.setString(_kBridgeWords, jsonEncode(map));
      await getStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error recording bridge word: $e');
    }
  }

  Future<void> recordGameResult({
    required bool converged,
    required int rounds,
    String? twinnedWord,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final played = (prefs.getInt(_kGamesPlayed) ?? 0) + 1;
      final roundsCount = (prefs.getInt(_kRoundsPlayed) ?? 0) + rounds;

      await prefs.setInt(_kGamesPlayed, played);
      await prefs.setInt(_kRoundsPlayed, roundsCount);

      if (converged) {
        final twinned = (prefs.getInt(_kGamesTwinned) ?? 0) + 1;
        await prefs.setInt(_kGamesTwinned, twinned);

        final prevFastest = prefs.getInt(_kFastestRounds);
        final newFastest = prevFastest == null ? rounds : min(prevFastest, rounds);
        await prefs.setInt(_kFastestRounds, newFastest);

        if (twinnedWord != null) {
          await recordRoundWord(twinnedWord);
        }
      }
      await getStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error recording game result: $e');
    }
  }
}
