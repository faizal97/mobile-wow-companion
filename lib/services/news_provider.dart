import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/news_article.dart';

/// Available news sources for filtering.
enum NewsSource { blizzard, wowhead, mmochampion, icyveins }

/// Content type categories for filtering.
enum NewsCategory {
  all,
  patchNotes,
  hotfix,
  guide,
  datamining,
  bluePost,
  community;

  String get displayName {
    switch (this) {
      case NewsCategory.all: return 'All';
      case NewsCategory.patchNotes: return 'Patch Notes';
      case NewsCategory.hotfix: return 'Hotfixes';
      case NewsCategory.guide: return 'Guides';
      case NewsCategory.datamining: return 'Datamining';
      case NewsCategory.bluePost: return 'Blue Posts';
      case NewsCategory.community: return 'Community';
    }
  }

  bool matches(String category) {
    if (this == NewsCategory.all) return true;
    switch (this) {
      case NewsCategory.patchNotes:
        return category.toLowerCase().contains('patch');
      case NewsCategory.hotfix:
        return category.toLowerCase().contains('hotfix');
      case NewsCategory.guide:
        return category.toLowerCase().contains('guide');
      case NewsCategory.datamining:
        return category.toLowerCase().contains('datamin');
      case NewsCategory.bluePost:
        return category.toLowerCase().contains('blue');
      case NewsCategory.community:
        return category.toLowerCase().contains('community');
      default:
        return false;
    }
  }
}

class NewsProvider extends ChangeNotifier {
  static const _cacheKey = 'news_articles_cache';
  static const _cacheTimestampKey = 'news_articles_timestamp';
  static const _stalenessDuration = Duration(minutes: 30);
  static const _rateLimitDuration = Duration(minutes: 2);

  static String get _baseUrl => AppConfig.authProxyUrl;

  final SharedPreferences _prefs;

  List<NewsArticle> _allArticles = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  String _searchQuery = '';

  // Filter state
  final Set<NewsSource> _selectedSources = {};
  final Set<NewsCategory> _selectedCategories = {};

  NewsProvider(this._prefs) {
    _loadCache();
  }

  // --- Getters ---
  List<NewsArticle> get articles => _filteredArticles;
  List<NewsArticle> get allArticles => _allArticles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<NewsSource> get selectedSources => _selectedSources;
  Set<NewsCategory> get selectedCategories => _selectedCategories;
  String get searchQuery => _searchQuery;

  int get activeFilterCount =>
      _selectedSources.length + _selectedCategories.length;

  bool get hasActiveFilters =>
      _selectedSources.isNotEmpty ||
      _selectedCategories.isNotEmpty ||
      _searchQuery.isNotEmpty;

  /// Latest 4 articles for the dashboard preview card.
  List<NewsArticle> get previewArticles {
    final sorted = List<NewsArticle>.from(_allArticles)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return sorted.take(4).toList();
  }

  List<NewsArticle> get _filteredArticles {
    var result = List<NewsArticle>.from(_allArticles);

    // Source filter
    if (_selectedSources.isNotEmpty) {
      result = result.where((a) {
        final source = NewsSource.values.where(
          (s) => s.name == a.source,
        );
        return source.isNotEmpty && _selectedSources.contains(source.first);
      }).toList();
    }

    // Category filter
    if (_selectedCategories.isNotEmpty &&
        !_selectedCategories.contains(NewsCategory.all)) {
      result = result.where((a) {
        return _selectedCategories.any((cat) => cat.matches(a.category));
      }).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((a) =>
        a.title.toLowerCase().contains(q) ||
        a.summary.toLowerCase().contains(q)).toList();
    }

    // Sort by date descending
    result.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return result;
  }

  // --- Actions ---

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void applyFilters({
    required Set<NewsSource> sources,
    required Set<NewsCategory> categories,
  }) {
    _selectedSources
      ..clear()
      ..addAll(sources);
    _selectedCategories
      ..clear()
      ..addAll(categories);
    notifyListeners();
  }

  void clearFilters() {
    _selectedSources.clear();
    _selectedCategories.clear();
    _searchQuery = '';
    notifyListeners();
  }

  /// Fetch on screen load — respects staleness window.
  Future<void> fetchNews() async {
    if (_allArticles.isNotEmpty && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < _stalenessDuration) return;
    }
    await _doFetch();
  }

  /// Pull-to-refresh — bypasses staleness but respects rate limit.
  Future<void> refreshNews() async {
    if (_lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < _rateLimitDuration) return;
    }
    await _doFetch();
  }

  Future<void> _doFetch() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sources = ['blizzard', 'wowhead', 'mmochampion', 'icyveins'];
      final futures = sources.map((s) => _fetchSource(s));
      final results = await Future.wait(futures);

      final all = <NewsArticle>[];
      for (final articles in results) {
        all.addAll(articles);
      }

      if (all.isNotEmpty) {
        _allArticles = all;
        _lastFetchTime = DateTime.now();
        _saveCache();
      } else if (_allArticles.isEmpty) {
        _errorMessage = 'No articles available';
      }
    } catch (e) {
      if (_allArticles.isEmpty) {
        _errorMessage = 'Failed to load news';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<NewsArticle>> _fetchSource(String source) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/news/$source'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((j) => NewsArticle.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('News fetch failed for $source: $e');
    }
    return [];
  }

  /// Fetch full article content for the reader view.
  Future<Map<String, dynamic>?> fetchArticleContent(String articleUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/news/article?url=${Uri.encodeComponent(articleUrl)}'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Article content fetch failed: $e');
    }
    return null;
  }

  // --- Cache ---

  void _loadCache() {
    final cached = _prefs.getString(_cacheKey);
    final timestamp = _prefs.getInt(_cacheTimestampKey);
    if (cached != null && timestamp != null) {
      try {
        final List<dynamic> data = jsonDecode(cached);
        _allArticles = data.map((j) => NewsArticle.fromJson(j as Map<String, dynamic>)).toList();
        _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } catch (_) {}
    }
  }

  void _saveCache() {
    final data = _allArticles.map((a) => a.toJson()).toList();
    _prefs.setString(_cacheKey, jsonEncode(data));
    _prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }
}

class RedditProvider extends ChangeNotifier {
  static const _cacheKey = 'reddit_posts_cache';
  static const _cacheTimestampKey = 'reddit_posts_timestamp';
  static const _stalenessDuration = Duration(minutes: 30);
  static const _rateLimitDuration = Duration(minutes: 2);

  static String get _baseUrl => AppConfig.authProxyUrl;

  final SharedPreferences _prefs;

  List<RedditPost> _posts = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  bool _showReddit = true;

  RedditProvider(this._prefs) {
    _showReddit = _prefs.getBool('reddit_show') ?? true;
    _loadCache();
  }

  List<RedditPost> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get showReddit => _showReddit;

  void setShowReddit(bool value) {
    _showReddit = value;
    _prefs.setBool('reddit_show', value);
    notifyListeners();
  }

  Future<void> fetchPosts() async {
    if (_posts.isNotEmpty && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < _stalenessDuration) return;
    }
    await _doFetch();
  }

  Future<void> refreshPosts() async {
    if (_lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < _rateLimitDuration) return;
    }
    await _doFetch();
  }

  Future<void> _doFetch() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_baseUrl/news/reddit'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _posts = data.map((j) => RedditPost.fromJson(j as Map<String, dynamic>)).toList();
        _lastFetchTime = DateTime.now();
        _saveCache();
      } else if (_posts.isEmpty) {
        _errorMessage = 'Reddit unavailable';
      }
    } catch (e) {
      if (_posts.isEmpty) {
        _errorMessage = 'Failed to load Reddit';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadCache() {
    final cached = _prefs.getString(_cacheKey);
    final timestamp = _prefs.getInt(_cacheTimestampKey);
    if (cached != null && timestamp != null) {
      try {
        final List<dynamic> data = jsonDecode(cached);
        _posts = data.map((j) => RedditPost.fromJson(j as Map<String, dynamic>)).toList();
        _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } catch (_) {}
    }
  }

  void _saveCache() {
    final data = _posts.map((p) => {
      'id': p.id, 'title': p.title, 'imageUrl': p.imageUrl,
      'summary': p.summary, 'author': p.author,
      'publishedAt': p.publishedAt.toIso8601String(),
      'url': p.url, 'score': p.score,
      'numComments': p.numComments, 'flair': p.flair,
    }).toList();
    _prefs.setString(_cacheKey, jsonEncode(data));
    _prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }
}
