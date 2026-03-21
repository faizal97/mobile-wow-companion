import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/mount.dart';
import '../services/mount_provider.dart';
import '../theme/app_theme.dart';

// ─── Screen ─────────────────────────────────────────────────────────────────

class MountJournalScreen extends StatefulWidget {
  const MountJournalScreen({super.key});

  @override
  State<MountJournalScreen> createState() => _MountJournalScreenState();
}

class _MountJournalScreenState extends State<MountJournalScreen> {
  bool _isGridView = false;
  int _collectionTab = 0; // 0=All, 1=Collected, 2=Missing
  bool _showFavoritesOnly = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showSearch = false;
  int _sortMode = 0; // 0=Collected first, 1=A-Z, 2=Z-A

  // Advanced filters
  final Set<String> _selectedExpansions = {};
  final Set<String> _selectedCategories = {};
  final Set<MountSourceGroup> _selectedSources = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MountProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount =>
      _selectedExpansions.length +
      _selectedCategories.length +
      _selectedSources.length;

  List<Mount> _filterMounts(List<Mount> mounts) {
    var result = mounts;

    // Collection tab
    if (_collectionTab == 1) {
      result = result.where((m) => m.isCollected).toList();
    } else if (_collectionTab == 2) {
      result = result.where((m) => !m.isCollected).toList();
    }

    // Favorites
    if (_showFavoritesOnly) {
      result = result.where((m) => m.isFavorite).toList();
    }

    // Expansion + Category filter (OR)
    if (_selectedExpansions.isNotEmpty || _selectedCategories.isNotEmpty) {
      result = result.where((m) {
        if (m.expansion == null) return false;
        return _selectedExpansions.contains(m.expansion) ||
            _selectedCategories.contains(m.expansion);
      }).toList();
    }

    // Source group filter
    if (_selectedSources.isNotEmpty) {
      result = result.where((m) {
        final group = m.sourceGroup;
        if (group == null) return false;
        return _selectedSources.contains(group);
      }).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((m) => m.name.toLowerCase().contains(q)).toList();
    }

    // Sort
    switch (_sortMode) {
      case 0: // Collected first, then alphabetical within each group
        result.sort((a, b) {
          if (a.isCollected != b.isCollected) {
            return a.isCollected ? -1 : 1;
          }
          return a.name.compareTo(b.name);
        });
        break;
      case 1: // A-Z
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 2: // Z-A
        result.sort((a, b) => b.name.compareTo(a.name));
        break;
    }

    return result;
  }

  bool get _hasActiveFilters =>
      _activeFilterCount > 0 || _showFavoritesOnly || _searchQuery.isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _selectedExpansions.clear();
      _selectedCategories.clear();
      _selectedSources.clear();
      _showFavoritesOnly = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MountProvider>(
      builder: (context, provider, _) {
        final filtered = _filterMounts(provider.mounts);

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.3, 1.0],
                colors: [
                  Color(0xFF101018),
                  AppTheme.background,
                  AppTheme.background,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(provider),
                  if (_showSearch) _buildSearchBar(),
                  _buildCollectionTabs(),
                  _buildToolbar(filtered.length, provider),
                  Expanded(
                    child: provider.isJournalLoading
                        ? _buildLoadingState()
                        : provider.error != null && provider.mounts.isEmpty
                            ? _buildErrorState(provider)
                            : RefreshIndicator(
                                onRefresh: () => provider.refresh(),
                                color: const Color(0xFF3FC7EB),
                                backgroundColor: AppTheme.surfaceElevated,
                                child: filtered.isEmpty
                                    ? ListView(
                                        children: [
                                          SizedBox(
                                            height: MediaQuery.of(context).size.height * 0.4,
                                            child: _buildEmptyState(),
                                          ),
                                        ],
                                      )
                                    : _isGridView
                                        ? _buildGridView(filtered, provider)
                                        : _buildListView(filtered, provider),
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(MountProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOUNT JOURNAL',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary,
                    letterSpacing: 2,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Mounts',
                      style: GoogleFonts.rajdhani(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (provider.mounts.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3FC7EB)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF3FC7EB)
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '${provider.collectedCount} / ${provider.totalCount}',
                          style: GoogleFonts.rajdhani(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3FC7EB),
                          ),
                        ),
                      ),
                    if (provider.isCollectionLoading)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFF3FC7EB),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _HeaderAction(
            icon: _showFavoritesOnly
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: _showFavoritesOnly ? const Color(0xFFFFD700) : null,
            onTap: () =>
                setState(() => _showFavoritesOnly = !_showFavoritesOnly),
          ),
          const SizedBox(width: 4),
          _HeaderAction(
            icon: _showSearch
                ? Icons.search_off_rounded
                : Icons.search_rounded,
            color: _showSearch ? const Color(0xFF3FC7EB) : null,
            onTap: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          const SizedBox(width: 4),
          _HeaderAction(
            icon: _isGridView
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded,
            onTap: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
    );
  }

  // ─── Search bar ──────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style:
              GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search mounts...',
            hintStyle: GoogleFonts.inter(
                fontSize: 14, color: AppTheme.textTertiary),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppTheme.textTertiary, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textTertiary, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // ─── Collection tabs ─────────────────────────────────────────────────────

  Widget _buildCollectionTabs() {
    final tabs = ['All', 'Collected', 'Missing'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = _collectionTab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _collectionTab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF3FC7EB)
                            .withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[i],
                    style: GoogleFonts.rajdhani(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? const Color(0xFF3FC7EB)
                          : AppTheme.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── Toolbar ─────────────────────────────────────────────────────────────

  Widget _buildToolbar(int count, MountProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? 'MOUNT' : 'MOUNTS'}',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (_hasActiveFilters)
            GestureDetector(
              onTap: _clearAllFilters,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  'Clear',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textTertiary),
                ),
              ),
            ),
          // Sort button
          GestureDetector(
            onTap: () => setState(() => _sortMode = (_sortMode + 1) % 3),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _sortMode != 0
                    ? const Color(0xFF3FC7EB).withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _sortMode != 0
                      ? const Color(0xFF3FC7EB).withValues(alpha: 0.3)
                      : AppTheme.surfaceBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sortMode == 2
                        ? Icons.sort_by_alpha_rounded
                        : Icons.sort_rounded,
                    size: 14,
                    color: _sortMode != 0
                        ? const Color(0xFF3FC7EB)
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sortMode == 0
                        ? 'Collected'
                        : _sortMode == 1
                            ? 'A–Z'
                            : 'Z–A',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _sortMode != 0
                          ? const Color(0xFF3FC7EB)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Filter button
          GestureDetector(
            onTap: () => _showFilterSheet(provider),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _activeFilterCount > 0
                    ? const Color(0xFF3FC7EB).withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _activeFilterCount > 0
                      ? const Color(0xFF3FC7EB).withValues(alpha: 0.3)
                      : AppTheme.surfaceBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded,
                      size: 14,
                      color: _activeFilterCount > 0
                          ? const Color(0xFF3FC7EB)
                          : AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Filters',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _activeFilterCount > 0
                          ? const Color(0xFF3FC7EB)
                          : AppTheme.textSecondary,
                    ),
                  ),
                  if (_activeFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF3FC7EB),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_activeFilterCount',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.background,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Grid view ───────────────────────────────────────────────────────────

  Widget _buildGridView(List<Mount> mounts, MountProvider provider) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: mounts.length,
      itemBuilder: (context, index) => _MountGridTile(
        mount: mounts[index],
        onTap: () => _showMountDetail(mounts[index], provider),
      ),
    );
  }

  // ─── List view ───────────────────────────────────────────────────────────

  Widget _buildListView(List<Mount> mounts, MountProvider provider) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: mounts.length,
      itemBuilder: (context, index) => _MountListTile(
        mount: mounts[index],
        onTap: () => _showMountDetail(mounts[index], provider),
      ),
    );
  }

  // ─── Loading state ───────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF3FC7EB)),
    );
  }

  // ─── Error state ─────────────────────────────────────────────────────────

  Widget _buildErrorState(MountProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48,
              color: AppTheme.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            provider.error ?? 'Something went wrong',
            style: GoogleFonts.rajdhani(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => provider.loadAll(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF3FC7EB).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Try again',
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF3FC7EB)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ─────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets_rounded,
              size: 48,
              color: AppTheme.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No mounts found',
            style: GoogleFonts.rajdhani(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your filters',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.textTertiary),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _clearAllFilters,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        const Color(0xFF3FC7EB).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Clear all filters',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF3FC7EB)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Mount detail bottom sheet ───────────────────────────────────────────

  void _showMountDetail(Mount mount, MountProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _MountDetailSheet(mount: mount, provider: provider),
    );
  }

  // ─── Filter bottom sheet ─────────────────────────────────────────────────

  void _showFilterSheet(MountProvider provider) {
    final tempExpansions = Set<String>.from(_selectedExpansions);
    final tempCategories = Set<String>.from(_selectedCategories);
    final tempSources = Set<MountSourceGroup>.from(_selectedSources);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final totalFilters = tempExpansions.length +
                tempCategories.length +
                tempSources.length;

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.92,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 32,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceBorder,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                'Filters',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (totalFilters > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3FC7EB)
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$totalFilters active',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF3FC7EB),
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (totalFilters > 0)
                                GestureDetector(
                                  onTap: () => setSheetState(() {
                                    tempExpansions.clear();
                                    tempCategories.clear();
                                    tempSources.clear();
                                  }),
                                  child: Text(
                                    'Reset',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Filter sections
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding:
                            const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        children: [
                          // Expansion
                          _FilterSectionHeader(title: 'EXPANSION'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                provider.expansions.map((exp) {
                              final sel =
                                  tempExpansions.contains(exp);
                              return _FilterTag(
                                label: exp,
                                isSelected: sel,
                                color: const Color(0xFF3FC7EB),
                                onTap: () => setSheetState(() {
                                  sel
                                      ? tempExpansions.remove(exp)
                                      : tempExpansions.add(exp);
                                }),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Category
                          _FilterSectionHeader(title: 'CATEGORY'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                provider.categories.map((cat) {
                              final sel =
                                  tempCategories.contains(cat);
                              return _FilterTag(
                                label: cat,
                                isSelected: sel,
                                color: const Color(0xFFE6CC80),
                                onTap: () => setSheetState(() {
                                  sel
                                      ? tempCategories.remove(cat)
                                      : tempCategories.add(cat);
                                }),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Source (icon grid)
                          _FilterSectionHeader(title: 'SOURCE'),
                          const SizedBox(height: 8),
                          _SourceGroupGrid(
                            counts: provider.sourceGroupCounts,
                            selected: tempSources,
                            onToggle: (group) => setSheetState(() {
                              tempSources.contains(group)
                                  ? tempSources.remove(group)
                                  : tempSources.add(group);
                            }),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),

                    // Apply
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: SafeArea(
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedExpansions
                                  ..clear()
                                  ..addAll(tempExpansions);
                                _selectedCategories
                                  ..clear()
                                  ..addAll(tempCategories);
                                _selectedSources
                                  ..clear()
                                  ..addAll(tempSources);
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF3FC7EB),
                              foregroundColor: AppTheme.background,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              totalFilters > 0
                                  ? 'Apply $totalFilters ${totalFilters == 1 ? 'Filter' : 'Filters'}'
                                  : 'Apply Filters',
                              style: GoogleFonts.rajdhani(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Header action button ───────────────────────────────────────────────────

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _HeaderAction(
      {required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color:
              color != null ? c.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color != null
                ? c.withValues(alpha: 0.2)
                : AppTheme.surfaceBorder,
          ),
        ),
        child: Icon(icon, color: c, size: 18),
      ),
    );
  }
}

// ─── Filter helpers ─────────────────────────────────────────────────────────

class _FilterSectionHeader extends StatelessWidget {
  final String title;
  const _FilterSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textTertiary,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _FilterTag extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterTag({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : AppTheme.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Source group grid (2-column icon grid for filter sheet) ────────────────

class _SourceGroupGrid extends StatelessWidget {
  final Map<MountSourceGroup, int> counts;
  final Set<MountSourceGroup> selected;
  final void Function(MountSourceGroup) onToggle;

  const _SourceGroupGrid({
    required this.counts,
    required this.selected,
    required this.onToggle,
  });

  static const _groupMeta = <MountSourceGroup, ({String label, IconData icon, Color color})>{
    MountSourceGroup.drops: (label: 'Drops', icon: Icons.casino_rounded, color: Color(0xFFA335EE)),
    MountSourceGroup.vendor: (label: 'Vendor', icon: Icons.storefront_rounded, color: Color(0xFFFFD700)),
    MountSourceGroup.quest: (label: 'Quest', icon: Icons.auto_stories_rounded, color: Color(0xFFFFFF00)),
    MountSourceGroup.achievement: (label: 'Achievement', icon: Icons.emoji_events_rounded, color: Color(0xFF1EFF00)),
    MountSourceGroup.reputation: (label: 'Reputation', icon: Icons.handshake_rounded, color: Color(0xFFFF8000)),
    MountSourceGroup.exploration: (label: 'Exploration', icon: Icons.explore_rounded, color: Color(0xFF71D5FF)),
    MountSourceGroup.promotion: (label: 'Promotion', icon: Icons.card_giftcard_rounded, color: Color(0xFF00CCFF)),
    MountSourceGroup.events: (label: 'Events', icon: Icons.celebration_rounded, color: Color(0xFFFF5E5B)),
  };

  @override
  Widget build(BuildContext context) {
    final groups = MountSourceGroup.values;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.8,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final meta = _groupMeta[group]!;
        final isSelected = selected.contains(group);
        final count = counts[group] ?? 0;

        return GestureDetector(
          onTap: () => onToggle(group),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? meta.color.withValues(alpha: 0.12)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? meta.color.withValues(alpha: 0.4)
                    : AppTheme.surfaceBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  meta.icon,
                  size: 18,
                  color: isSelected ? meta.color : AppTheme.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        meta.label,
                        style: GoogleFonts.rajdhani(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? meta.color
                              : AppTheme.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '$count mounts',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: isSelected
                              ? meta.color.withValues(alpha: 0.7)
                              : AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Mount icon with fallback ───────────────────────────────────────────────

class _MountIcon extends StatelessWidget {
  final Mount mount;
  final double size;

  const _MountIcon({required this.mount, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final url = mount.spellIconUrl;
    final isCollected = mount.isCollected;

    Widget image;
    if (url != null) {
      image = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    } else {
      image = _placeholder();
    }

    if (!isCollected) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: Opacity(opacity: 0.35, child: image),
      );
    }

    return SizedBox(width: size, height: size, child: image);
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surface,
      child: Center(
        child: Icon(Icons.pets_rounded,
            color: AppTheme.textTertiary.withValues(alpha: 0.3),
            size: size * 0.4),
      ),
    );
  }
}

// ─── Grid tile ──────────────────────────────────────────────────────────────

class _MountGridTile extends StatelessWidget {
  final Mount mount;
  final VoidCallback onTap;

  const _MountGridTile({required this.mount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Grid: prefer zoom render (3D model), fall back to spell icon
    final imageUrl = mount.zoomImageUrl ?? mount.spellIconUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mount.isCollected
                ? const Color(0xFF3FC7EB).withValues(alpha: 0.2)
                : AppTheme.surfaceBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Mount model image
            Positioned.fill(
              child: _GridImage(imageUrl: imageUrl, isCollected: mount.isCollected),
            ),

            // Bottom gradient + name
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: Text(
                  mount.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: mount.isCollected
                        ? AppTheme.textPrimary
                        : AppTheme.textTertiary,
                    height: 1.15,
                  ),
                ),
              ),
            ),

            if (mount.isFavorite)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.star_rounded,
                    size: 14, color: Color(0xFFFFD700)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grid image: zoom render → spell icon → placeholder, with desaturation for uncollected.
class _GridImage extends StatelessWidget {
  final String? imageUrl;
  final bool isCollected;

  const _GridImage({required this.imageUrl, required this.isCollected});

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (imageUrl != null) {
      image = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    } else {
      image = _placeholder();
    }

    if (!isCollected) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: Opacity(opacity: 0.35, child: image),
      );
    }

    return image;
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surface,
      child: Center(
        child: Icon(Icons.pets_rounded,
            color: AppTheme.textTertiary.withValues(alpha: 0.3), size: 28),
      ),
    );
  }
}

// ─── List tile ──────────────────────────────────────────────────────────────

class _MountListTile extends StatelessWidget {
  final Mount mount;
  final VoidCallback onTap;

  const _MountListTile({required this.mount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mount.isCollected
                ? const Color(0xFF3FC7EB).withValues(alpha: 0.15)
                : AppTheme.surfaceBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: mount.isCollected
                      ? const Color(0xFF3FC7EB).withValues(alpha: 0.2)
                      : AppTheme.surfaceBorder,
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _MountIcon(mount: mount),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mount.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: mount.isCollected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildSubtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
            if (mount.isFavorite)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.star_rounded,
                    size: 14, color: Color(0xFFFFD700)),
              ),
            Icon(
              mount.isCollected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 18,
              color: mount.isCollected
                  ? const Color(0xFF1EFF00).withValues(alpha: 0.6)
                  : AppTheme.textTertiary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (mount.sourceSubcategory != null) parts.add(mount.sourceSubcategory!);
    if (mount.expansion != null) parts.add(mount.expansion!);
    if (parts.isEmpty) return 'Unknown source';
    return parts.join(' · ');
  }
}

// ─── Mount detail bottom sheet ──────────────────────────────────────────────

class _MountDetailSheet extends StatefulWidget {
  final Mount mount;
  final MountProvider provider;

  const _MountDetailSheet(
      {required this.mount, required this.provider});

  @override
  State<_MountDetailSheet> createState() => _MountDetailSheetState();
}

class _MountDetailSheetState extends State<_MountDetailSheet> {
  MountDetail? _detail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Only fetch Blizzard detail if we need zoom render (no creatureDisplayId yet)
    if (widget.mount.creatureDisplayId == null) {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    final cached = widget.provider.getCachedDetail(widget.mount.id);
    if (cached != null) {
      setState(() => _detail = cached);
      return;
    }

    setState(() => _isLoading = true);
    final detail = await widget.provider.fetchMountDetail(widget.mount.id);
    if (mounted) {
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mount = widget.mount;
    final imageUrl = mount.zoomImageUrl ?? _detail?.zoomImageUrl ?? mount.spellIconUrl;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Mount image
            Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3FC7EB).withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _isLoading
                            ? _loadingPlaceholder()
                            : _placeholder(),
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _isLoading
                        ? _loadingPlaceholder()
                        : _placeholder(),
              ),
            ),
            const SizedBox(height: 20),

            // Name + collected badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    mount.name,
                    style: GoogleFonts.rajdhani(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: mount.isCollected
                        ? const Color(0xFF1EFF00).withValues(alpha: 0.1)
                        : AppTheme.surfaceBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: mount.isCollected
                          ? const Color(0xFF1EFF00).withValues(alpha: 0.25)
                          : AppTheme.surfaceBorder,
                    ),
                  ),
                  child: Text(
                    mount.isCollected ? 'COLLECTED' : 'NOT COLLECTED',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: mount.isCollected
                          ? const Color(0xFF1EFF00)
                          : AppTheme.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Info tags row
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (mount.sourceSubcategory != null)
                  _DetailTag(
                    dotColor: const Color(0xFFA335EE),
                    label: mount.sourceSubcategory!,
                  ),
                if (mount.expansion != null)
                  _DetailTag(
                    dotColor: const Color(0xFF3FC7EB),
                    label: mount.expansion!,
                  ),
                if (mount.mountType != null)
                  _DetailTag(
                    icon: mount.mountType!.icon,
                    dotColor: const Color(0xFF8888A0),
                    label: mount.mountType!.label,
                  ),
              ],
            ),

            // How to Obtain section
            if (mount.acquisition != null &&
                mount.acquisition!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DetailSection(
                title: 'HOW TO OBTAIN',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: mount.acquisition!.fields.entries.map((e) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: e.key == mount.acquisition!.fields.keys.last
                            ? 0
                            : 6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              e.key,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.value,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Boss/Instance section (for drop mounts)
            if (mount.bossDescription != null &&
                mount.bossDescription!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailSection(
                title: mount.bossName != null
                    ? '${mount.bossName!.toUpperCase()} — ${mount.instanceName ?? ''}'.toUpperCase()
                    : 'ENCOUNTER',
                child: Text(
                  mount.bossDescription!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            // Requirement section
            if (mount.requirement != null &&
                mount.requirement!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8000).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF8000).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: const Color(0xFFFF8000).withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mount.requirement!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFFF8000),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Lore/Description section
            if (mount.description != null &&
                mount.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailSection(
                title: 'LORE',
                child: Text(
                  mount.description!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.surface,
        child: Center(
          child: Icon(Icons.pets_rounded,
              color: AppTheme.textTertiary.withValues(alpha: 0.3), size: 48),
        ),
      );

  Widget _loadingPlaceholder() => Container(
        color: AppTheme.surface,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF3FC7EB)),
          ),
        ),
      );
}

/// A labeled section card for the detail sheet.
class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DetailTag extends StatelessWidget {
  final Color dotColor;
  final String label;
  final IconData? icon;

  const _DetailTag({required this.dotColor, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 12, color: dotColor)
        else
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(fontSize: 13, color: dotColor)),
      ],
    );
  }
}
