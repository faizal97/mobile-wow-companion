import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/achievement_provider.dart';
import '../services/character_provider.dart';
import '../theme/app_theme.dart';
import 'achievement_category_screen.dart';
import 'character_list_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Text(
                  'WOW WARBAND',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Companion',
                  style: GoogleFonts.rajdhani(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 48),
                _MenuCard(
                  icon: Icons.people_rounded,
                  title: 'Characters',
                  subtitle: _buildCharacterSubtitle(context),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CharacterListScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _MenuCard(
                  icon: Icons.emoji_events_rounded,
                  title: 'Achievements',
                  subtitle: _buildAchievementSubtitle(context),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AchievementCategoryScreen()),
                  ),
                ),
                const Spacer(),
                Center(
                  child: TextButton(
                    onPressed: () => _showSettings(context),
                    child: Text(
                      'Settings',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildCharacterSubtitle(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    if (provider.hasCharacters) {
      return '${provider.characters.length} characters';
    }
    return 'View your warband';
  }

  String _buildAchievementSubtitle(BuildContext context) {
    final provider = context.watch<AchievementProvider>();
    final points = provider.progress?.totalPoints;
    if (points != null && points > 0) {
      return '$points points';
    }
    return 'Track your progress';
  }

  void _showSettings(BuildContext context) {
    final provider = context.read<CharacterProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
              title: Text(
                'Sign Out',
                style: GoogleFonts.inter(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                provider.logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF3FC7EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF3FC7EB), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.rajdhani(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textTertiary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
