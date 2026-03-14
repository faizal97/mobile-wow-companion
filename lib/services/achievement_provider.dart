import 'package:flutter/foundation.dart';
import '../models/achievement.dart';
import 'battlenet_api_service.dart';
import 'character_cache_service.dart';

/// A display-ready achievement merged with player progress.
class AchievementDisplay {
  final Achievement achievement;
  final bool isCompleted;
  final int? completedTimestamp;
  final Map<int, bool> criteriaProgress;
  final int completedCriteria;
  final int totalCriteria;

  const AchievementDisplay({
    required this.achievement,
    required this.isCompleted,
    this.completedTimestamp,
    this.criteriaProgress = const {},
    this.completedCriteria = 0,
    this.totalCriteria = 0,
  });

  String? get formattedDate {
    if (completedTimestamp == null) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(completedTimestamp!);
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Result of merging achievement definitions with progress.
class MergedAchievements {
  final List<AchievementDisplay> completed;
  final List<AchievementDisplay> incomplete;

  const MergedAchievements({
    required this.completed,
    required this.incomplete,
  });

  List<AchievementDisplay> get all => [...incomplete, ...completed];
}

/// Manages achievement state: categories, definitions, and player progress.
class AchievementProvider extends ChangeNotifier {
  final BattleNetApiService _apiService;
  final CharacterCacheService _cacheService;

  List<AchievementCategoryRef> _topCategories = [];
  AccountAchievementProgress? _progress;
  bool _isCategoriesLoading = false;
  bool _isProgressLoading = false;
  String? _error;

  // Per-category state
  final Map<int, AchievementCategory> _categoryDetails = {};
  final Map<int, List<Achievement>> _categoryAchievements = {};
  final Map<int, bool> _categoryLoading = {};

  AchievementProvider(this._apiService, this._cacheService);

  List<AchievementCategoryRef> get topCategories => _topCategories;
  AccountAchievementProgress? get progress => _progress;
  bool get isCategoriesLoading => _isCategoriesLoading;
  bool get isProgressLoading => _isProgressLoading;
  String? get error => _error;

  bool isCategoryLoading(int categoryId) => _categoryLoading[categoryId] ?? false;

  AchievementCategory? getCategoryDetails(int categoryId) =>
      _categoryDetails[categoryId];

  List<Achievement>? getCategoryAchievements(int categoryId) =>
      _categoryAchievements[categoryId];

  /// Loads the top-level achievement categories.
  Future<void> loadCategories() async {
    _isCategoriesLoading = true;
    _error = null;
    notifyListeners();

    try {
      _topCategories = await _apiService.getAchievementCategoriesIndex();
    } catch (e) {
      _error = 'Failed to load categories';
    }

    _isCategoriesLoading = false;
    notifyListeners();
  }

  /// Loads account-wide achievement progress using any character.
  Future<void> loadProgress(String realmSlug, String characterName) async {
    _isProgressLoading = true;
    notifyListeners();

    try {
      _progress =
          await _apiService.getCharacterAchievements(realmSlug, characterName);
    } catch (_) {
      // Progress is optional — the UI still works without it
    }

    _isProgressLoading = false;
    notifyListeners();
  }

  /// Loads a specific category's details and achievement definitions.
  /// Uses cache first, fetches from API if missing/stale.
  Future<void> loadCategoryDetails(int categoryId) async {
    _categoryLoading[categoryId] = true;
    notifyListeners();

    // Check cache for category details
    var category = _cacheService.getCachedAchievementCategory(categoryId);
    if (category == null) {
      category = await _apiService.getAchievementCategory(categoryId);
      if (category != null) {
        _cacheService.cacheAchievementCategory(category);
      }
    }

    if (category != null) {
      _categoryDetails[categoryId] = category;
    }

    // Check cache for achievement definitions
    if (category != null && category.achievementRefs.isNotEmpty) {
      var achievements = _cacheService.getCachedAchievements(categoryId);
      if (achievements == null) {
        final ids = category.achievementRefs.map((r) => r.id).toList();
        achievements = await _apiService.getAchievements(ids);

        // Enrich with icons
        achievements = await _apiService.enrichAchievementIcons(achievements);

        if (achievements.isNotEmpty) {
          _cacheService.cacheAchievements(categoryId, achievements);
        }
      }
      _categoryAchievements[categoryId] = achievements;
    }

    _categoryLoading[categoryId] = false;
    notifyListeners();
  }

  /// Merges achievement definitions with player progress for display.
  /// Static so it can be tested without mocking the provider.
  static MergedAchievements mergeWithProgress(
    List<Achievement> achievements,
    AccountAchievementProgress? progress,
  ) {
    final completed = <AchievementDisplay>[];
    final incomplete = <AchievementDisplay>[];

    for (final ach in achievements) {
      final entry = progress?.achievements[ach.id];
      final isCompleted = entry?.isCompleted ?? false;

      int completedCriteria = 0;
      int totalCriteria = 0;

      if (ach.criteria != null && ach.criteria!.childCriteria.isNotEmpty) {
        totalCriteria = ach.criteria!.childCriteria.length;
        for (final child in ach.criteria!.childCriteria) {
          if (entry?.criteriaProgress[child.id] == true) {
            completedCriteria++;
          }
        }
      }

      final display = AchievementDisplay(
        achievement: ach,
        isCompleted: isCompleted,
        completedTimestamp: entry?.completedTimestamp,
        criteriaProgress: entry?.criteriaProgress ?? {},
        completedCriteria: completedCriteria,
        totalCriteria: totalCriteria,
      );

      if (isCompleted) {
        completed.add(display);
      } else {
        incomplete.add(display);
      }
    }

    // Sort completed by most recent first
    completed.sort((a, b) =>
        (b.completedTimestamp ?? 0).compareTo(a.completedTimestamp ?? 0));

    return MergedAchievements(completed: completed, incomplete: incomplete);
  }

  /// Gets merged achievements for display in a category.
  MergedAchievements? getMergedAchievements(int categoryId) {
    final achievements = _categoryAchievements[categoryId];
    if (achievements == null) return null;
    return mergeWithProgress(achievements, _progress);
  }

  /// Refresh progress data (pull-to-refresh).
  Future<void> refreshProgress(String realmSlug, String characterName) async {
    await loadProgress(realmSlug, characterName);
  }
}
