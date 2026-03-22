import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/wow_class_colors.dart';
import '../data/effect_types.dart';
import '../data/td_class_registry.dart';

// ---------------------------------------------------------------------------
// TdClassGuideScreen — class compendium with archetype tabs
// ---------------------------------------------------------------------------

class TdClassGuideScreen extends StatefulWidget {
  const TdClassGuideScreen({super.key});

  @override
  State<TdClassGuideScreen> createState() => _TdClassGuideScreenState();
}

class _TdClassGuideScreenState extends State<TdClassGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TdClassRegistry? _registry;
  bool _loading = true;

  static const _archetypes = [
    TowerArchetype.melee,
    TowerArchetype.ranged,
    TowerArchetype.support,
    TowerArchetype.aoe,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _archetypes.length, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final reg = TdClassRegistry();
    await reg.load();
    if (mounted) {
      setState(() {
        _registry = reg;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<TowerArchetype, List<TdClassDef>> _groupByArchetype() {
    final map = <TowerArchetype, List<TdClassDef>>{};
    for (final arch in _archetypes) {
      map[arch] = [];
    }
    if (_registry == null) return map;
    for (final name in _registry!.allClassNames) {
      final def = _registry!.getClass(name);
      map.putIfAbsent(def.archetype, () => []);
      map[def.archetype]!.add(def);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'CLASS COMPENDIUM',
          style: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFA335EE),
          indicatorWeight: 2,
          labelColor: const Color(0xFFA335EE),
          unselectedLabelColor: AppTheme.textTertiary,
          labelStyle: GoogleFonts.rajdhani(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
          unselectedLabelStyle: GoogleFonts.rajdhani(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
          tabs: const [
            Tab(text: 'MELEE'),
            Tab(text: 'RANGED'),
            Tab(text: 'SUPPORT'),
            Tab(text: 'AOE'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFA335EE),
                strokeWidth: 2,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: _archetypes.map((arch) {
                final classes = _groupByArchetype()[arch] ?? [];
                return _buildArchetypeTab(arch, classes);
              }).toList(),
            ),
    );
  }

  static String _fallbackStats(TowerArchetype archetype) {
    switch (archetype) {
      case TowerArchetype.melee:
        return '1.0x damage  \u00B7  0.8s attack speed  \u00B7  targets closest enemy';
      case TowerArchetype.ranged:
        return '1.0x damage  \u00B7  1.0s attack speed  \u00B7  targets furthest enemy';
      case TowerArchetype.support:
        return 'No attack  \u00B7  buffs adjacent towers';
      case TowerArchetype.aoe:
        return '0.5x damage  \u00B7  1.3s attack speed  \u00B7  targets all enemies in lane';
    }
  }

  Widget _buildArchetypeTab(TowerArchetype archetype, List<TdClassDef> classes) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Archetype base stats header
        _buildArchetypeHeader(archetype),
        const SizedBox(height: 16),
        // Class cards
        ...classes.map((cls) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ClassCard(classDef: cls),
        )),
        if (classes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'No classes in this archetype',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildArchetypeHeader(TowerArchetype archetype) {
    // Read stats from JSON registry, with hardcoded fallbacks
    final info = _registry?.getArchetype(archetype);
    final stats = info?.stats ?? _fallbackStats(archetype);
    IconData icon;
    switch (archetype) {
      case TowerArchetype.melee:
        icon = Icons.sports_mma_rounded;
      case TowerArchetype.ranged:
        icon = Icons.gps_fixed_rounded;
      case TowerArchetype.support:
        icon = Icons.favorite_rounded;
      case TowerArchetype.aoe:
        icon = Icons.blur_on_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFA335EE), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  archetype.name.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFA335EE),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stats,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ClassCard — individual class card
// ---------------------------------------------------------------------------

class _ClassCard extends StatelessWidget {
  final TdClassDef classDef;

  const _ClassCard({required this.classDef});

  Color get _classColor => WowClassColors.forClass(classDef.name);

  String _displayName(String name) {
    return name
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final color = _classColor;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left color bar
              Container(width: 4, color: color),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: name + archetype badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _displayName(classDef.name),
                              style: GoogleFonts.rajdhani(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: color,
                                height: 1.2,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              classDef.archetype.name.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: color.withValues(alpha: 0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Passive section
                      Text(
                        classDef.passive.name,
                        style: GoogleFonts.rajdhani(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        classDef.passive.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Stats row
                      _buildStatsRow(color),
                      // Effects chips
                      if (classDef.passive.effects.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: classDef.passive.effects
                              .map((e) => _buildEffectChip(e, color))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(Color color) {
    String dmgText;
    String spdText;
    String targetText;

    switch (classDef.archetype) {
      case TowerArchetype.melee:
        dmgText = 'DMG: 1.0x';
        spdText = 'SPD: 0.8s';
        targetText = 'TARGET: Closest';
      case TowerArchetype.ranged:
        dmgText = 'DMG: 0.8x';
        spdText = 'SPD: 1.2s';
        targetText = 'TARGET: Furthest';
      case TowerArchetype.support:
        dmgText = 'DMG: N/A';
        spdText = 'SPD: N/A';
        targetText = 'ROLE: Buffer';
      case TowerArchetype.aoe:
        dmgText = 'DMG: 0.4x';
        spdText = 'SPD: 1.5s';
        targetText = 'TARGET: All in Lane';
    }

    final style = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppTheme.textTertiary,
      letterSpacing: 0.3,
    );

    return Row(
      children: [
        Text(dmgText, style: style),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('\u00B7', style: style),
        ),
        Text(spdText, style: style),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('\u00B7', style: style),
        ),
        Text(targetText, style: style),
      ],
    );
  }

  Widget _buildEffectChip(EffectDef effect, Color color) {
    final label = _effectLabel(effect);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  String _effectLabel(EffectDef effect) {
    switch (effect.type) {
      case 'extra_targets':
        return 'Extra Targets +${effect.value.toInt()}';
      case 'damage_multiplier':
        return '${effect.value.toStringAsFixed(0)}x Damage (every ${effect.params['nth'] ?? '?'}th)';
      case 'slow_enemy':
        return 'Slow ${(effect.value * 100).toInt()}% / ${effect.duration.toStringAsFixed(0)}s';
      case 'immune_to_affix':
        return 'Immune: ${(effect.params['affix'] as String? ?? '').toUpperCase()}';
      case 'attack_speed_multiplier':
        final pct = ((1.0 - effect.value) * 100).round();
        return 'Attack Speed +$pct%';
      case 'cross_lane_attack':
        return 'Cross-Lane Attack';
      case 'crit_chance':
        return 'Crit ${(effect.chance * 100).toInt()}% / ${effect.multiplier.toStringAsFixed(0)}x';
      case 'dot':
        return 'DoT ${(effect.value * 100).toInt()}% / ${effect.duration.toStringAsFixed(0)}s';
      case 'charge_attack':
        final chargeTime = (effect.params['chargeTime'] as num?)?.toDouble() ?? 0;
        return 'Charge ${chargeTime.toStringAsFixed(0)}s / ${effect.multiplier.toStringAsFixed(0)}x';
      case 'buff_adjacent_damage':
        return 'Buff DMG +${(effect.value * 100).toInt()}%';
      case 'buff_adjacent_speed':
        return 'Buff SPD +${(effect.value * 100).toInt()}%';
      case 'chain_damage':
        final bounces = effect.params['bounces'] as List?;
        return 'Chain ${bounces?.length ?? 0} Targets';
      default:
        return effect.type.replaceAll('_', ' ').toUpperCase();
    }
  }
}
