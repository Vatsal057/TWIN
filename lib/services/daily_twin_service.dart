import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyTwinPuzzle {
  const DailyTwinPuzzle({
    required this.puzzleNumber,
    required this.dateString,
    required this.startWordA,
    required this.startWordB,
    required this.timeRemaining,
  });

  final int puzzleNumber;
  final String dateString;
  final String startWordA;
  final String startWordB;
  final Duration timeRemaining;
}

class DailyTwinStatus {
  const DailyTwinStatus({
    required this.puzzle,
    required this.isCompletedToday,
    required this.currentStreak,
    required this.bestStreak,
  });

  final DailyTwinPuzzle puzzle;
  final bool isCompletedToday;
  final int currentStreak;
  final int bestStreak;
}

/// Manages the globally seeded daily 24-hour challenge and player streaks.
class DailyTwinService {
  DailyTwinService._();
  static final DailyTwinService instance = DailyTwinService._();

  static const _kLastCompletedDate = 'daily_last_completed_date';
  static const _kCurrentStreak = 'daily_current_streak';
  static const _kBestStreak = 'daily_best_streak';

  // Epoch anchor for puzzle numbering: 2026-01-01
  static final _epoch = DateTime.utc(2026, 1, 1);

  static const _curatedDailyPairs = <(String, String)>[
    ('Ocean', 'Desert'),
    ('Dawn', 'Dusk'),
    ('Silence', 'Echo'),
    ('Shadow', 'Mirror'),
    ('Mountain', 'Cloud'),
    ('Fire', 'Glass'),
    ('Memory', 'Future'),
    ('Labyrinth', 'Compass'),
    ('Anchor', 'Horizon'),
    ('Clock', 'River'),
    ('Thunder', 'Feather'),
    ('Castle', 'Ruins'),
    ('Galaxy', 'Dust'),
    ('Root', 'Star'),
    ('Poetry', 'Code'),
    ('Winter', 'Ember'),
    ('Gravity', 'Kite'),
    ('Secret', 'Key'),
    ('Canvas', 'Storm'),
    ('Voyage', 'Harbor'),
    ('Echo', 'Whisper'),
    ('Bridge', 'Abyss'),
    ('Lantern', 'Fog'),
    ('Sculpture', 'Clay'),
    ('Orbit', 'Tether'),
    ('Sun', 'Fossil'),
    ('Prism', 'Shadow'),
    ('Lighthouse', 'Shipwreck'),
    ('Melody', 'Clockwork'),
    ('Island', 'Current'),
  ];

  /// Returns today's UTC date as "YYYY-MM-DD".
  String get todayUtcString {
    final now = DateTime.now().toUtc();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Calculates today's global puzzle details.
  DailyTwinPuzzle getTodayPuzzle() {
    final now = DateTime.now().toUtc();
    final daysSinceEpoch = now.difference(_epoch).inDays;
    final puzzleNumber = max(1, daysSinceEpoch + 1);

    final pairIndex = daysSinceEpoch.abs() % _curatedDailyPairs.length;
    final pair = _curatedDailyPairs[pairIndex];

    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
    final remaining = tomorrow.difference(now);

    return DailyTwinPuzzle(
      puzzleNumber: puzzleNumber,
      dateString: todayUtcString,
      startWordA: pair.$1,
      startWordB: pair.$2,
      timeRemaining: remaining,
    );
  }

  Future<DailyTwinStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final puzzle = getTodayPuzzle();
    final lastDate = prefs.getString(_kLastCompletedDate);
    final isDoneToday = lastDate == todayUtcString;

    var currentStreak = prefs.getInt(_kCurrentStreak) ?? 0;
    final bestStreak = prefs.getInt(_kBestStreak) ?? 0;

    // Check if streak was broken (missed yesterday)
    if (!isDoneToday && lastDate != null) {
      final now = DateTime.now().toUtc();
      final yesterday = DateTime.utc(now.year, now.month, now.day - 1);
      final yStr =
          '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      if (lastDate != yStr) {
        currentStreak = 0;
        await prefs.setInt(_kCurrentStreak, 0);
      }
    }

    return DailyTwinStatus(
      puzzle: puzzle,
      isCompletedToday: isDoneToday,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
    );
  }

  Future<void> recordDailyCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString(_kLastCompletedDate);
      final today = todayUtcString;

      if (lastDate == today) return; // Already recorded today

      final now = DateTime.now().toUtc();
      final yesterday = DateTime.utc(now.year, now.month, now.day - 1);
      final yStr =
          '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      var currentStreak = prefs.getInt(_kCurrentStreak) ?? 0;
      var bestStreak = prefs.getInt(_kBestStreak) ?? 0;

      if (lastDate == yStr) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }

      bestStreak = max(bestStreak, currentStreak);

      await prefs.setString(_kLastCompletedDate, today);
      await prefs.setInt(_kCurrentStreak, currentStreak);
      await prefs.setInt(_kBestStreak, bestStreak);
    } catch (e) {
      debugPrint('Error recording daily completion: $e');
    }
  }
}
