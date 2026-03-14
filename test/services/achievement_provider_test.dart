import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/models/achievement.dart';
import 'package:wow_warband_companion/services/achievement_provider.dart';

void main() {
  group('AchievementProvider', () {
    test('mergeWithProgress marks completed achievements', () {
      final achievements = [
        Achievement(id: 6, name: 'Level 10', description: 'Reach 10', points: 10),
        Achievement(id: 7, name: 'Level 20', description: 'Reach 20', points: 10),
      ];
      final progress = AccountAchievementProgress(
        totalQuantity: 1,
        totalPoints: 10,
        achievements: {
          6: AchievementProgressEntry(
            achievementId: 6,
            isCompleted: true,
            completedTimestamp: 1600000000000,
            criteriaProgress: {},
          ),
        },
      );

      final merged = AchievementProvider.mergeWithProgress(achievements, progress);

      expect(merged.completed.length, 1);
      expect(merged.completed.first.achievement.id, 6);
      expect(merged.completed.first.isCompleted, true);
      expect(merged.incomplete.length, 1);
      expect(merged.incomplete.first.achievement.id, 7);
      expect(merged.incomplete.first.isCompleted, false);
    });

    test('mergeWithProgress calculates criteria completion counts', () {
      final achievements = [
        Achievement(
          id: 100,
          name: 'Explore',
          description: 'Explore all',
          points: 25,
          criteria: AchievementCriteria(
            id: 500,
            description: 'Root',
            childCriteria: [
              AchievementCriteria(id: 501, description: 'Zone A'),
              AchievementCriteria(id: 502, description: 'Zone B'),
              AchievementCriteria(id: 503, description: 'Zone C'),
            ],
          ),
        ),
      ];
      final progress = AccountAchievementProgress(
        totalQuantity: 0,
        totalPoints: 0,
        achievements: {
          100: AchievementProgressEntry(
            achievementId: 100,
            isCompleted: false,
            criteriaProgress: {500: false, 501: true, 502: true, 503: false},
          ),
        },
      );

      final merged = AchievementProvider.mergeWithProgress(achievements, progress);
      expect(merged.incomplete.length, 1);
      expect(merged.incomplete.first.completedCriteria, 2);
      expect(merged.incomplete.first.totalCriteria, 3);
    });

    test('mergeWithProgress with null progress treats all as incomplete', () {
      final achievements = [
        Achievement(id: 1, name: 'Test', description: '', points: 5),
      ];

      final merged = AchievementProvider.mergeWithProgress(achievements, null);
      expect(merged.completed, isEmpty);
      expect(merged.incomplete.length, 1);
    });

    test('completed sorted by most recent first', () {
      final achievements = [
        Achievement(id: 1, name: 'Old', description: '', points: 5),
        Achievement(id: 2, name: 'New', description: '', points: 5),
      ];
      final progress = AccountAchievementProgress(
        totalQuantity: 2,
        totalPoints: 10,
        achievements: {
          1: AchievementProgressEntry(achievementId: 1, isCompleted: true, completedTimestamp: 1000),
          2: AchievementProgressEntry(achievementId: 2, isCompleted: true, completedTimestamp: 2000),
        },
      );

      final merged = AchievementProvider.mergeWithProgress(achievements, progress);
      expect(merged.completed.first.achievement.id, 2); // most recent first
      expect(merged.completed.last.achievement.id, 1);
    });

    test('formattedDate returns correct format', () {
      const display = AchievementDisplay(
        achievement: Achievement(id: 1, name: 'Test', description: '', points: 0),
        isCompleted: true,
        completedTimestamp: 1545123240000, // Dec 18, 2018
      );
      expect(display.formattedDate, isNotNull);
      expect(display.formattedDate, contains('2018'));
    });

    test('formattedDate returns null when no timestamp', () {
      const display = AchievementDisplay(
        achievement: Achievement(id: 1, name: 'Test', description: '', points: 0),
        isCompleted: false,
      );
      expect(display.formattedDate, isNull);
    });
  });
}
