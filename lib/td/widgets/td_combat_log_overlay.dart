import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../models/td_combat_log.dart';

/// A collapsible combat log overlay for the TD game.
///
/// Collapsed: a small pill at bottom-left showing the latest event.
/// Expanded: a semi-transparent dark panel with a scrollable event list.
class TdCombatLogOverlay extends StatefulWidget {
  final List<TdCombatLogEntry> entries;
  final double uiScale;

  const TdCombatLogOverlay({
    super.key,
    required this.entries,
    required this.uiScale,
  });

  @override
  State<TdCombatLogOverlay> createState() => _TdCombatLogOverlayState();
}

class _TdCombatLogOverlayState extends State<TdCombatLogOverlay> {
  bool _isExpanded = false;
  final ScrollController _scrollController = ScrollController();
  int _lastEntryCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TdCombatLogOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.length != _lastEntryCount) {
      _lastEntryCount = widget.entries.length;
      if (_isExpanded) {
        _autoScroll();
      }
    }
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.position.pixels;
      if (max - current < 60) {
        _scrollController.jumpTo(max);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    return _isExpanded ? _buildExpanded() : _buildCollapsed();
  }

  // ---------------------------------------------------------------------------
  // Collapsed state
  // ---------------------------------------------------------------------------

  Widget _buildCollapsed() {
    final lastEntry = widget.entries.last;
    final s = widget.uiScale;

    return Align(
      alignment: Alignment.bottomLeft,
      child: GestureDetector(
        onTap: () {
          setState(() => _isExpanded = true);
          _lastEntryCount = widget.entries.length;
          _autoScroll();
        },
        child: Container(
          margin: EdgeInsets.only(left: 6 * s, bottom: 6 * s),
          padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 5 * s),
          constraints: BoxConstraints(maxWidth: 260 * s),
          decoration: BoxDecoration(
            color: const Color(0xCC0D0D14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppTheme.surfaceBorder.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scroll/log icon
              Icon(
                Icons.subject_rounded,
                size: 11 * s,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
              SizedBox(width: 5 * s),
              // Last event preview
              Flexible(
                child: Text(
                  lastEntry.message,
                  style: GoogleFonts.rajdhani(
                    fontSize: 10 * s,
                    color: lastEntry.color.withValues(alpha: 0.7),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 4 * s),
              // Entry count badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBorder.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.entries.length}',
                  style: GoogleFonts.rajdhani(
                    fontSize: 8 * s,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Expanded state
  // ---------------------------------------------------------------------------

  Widget _buildExpanded() {
    final s = widget.uiScale;
    final panelHeight = 150.0 * s;

    return SizedBox(
      height: panelHeight,
      child: GestureDetector(
        onTap: () {}, // absorb taps so lanes beneath aren't triggered
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE80D0D14),
            border: Border(
              top: BorderSide(
                color: AppTheme.surfaceBorder.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(s),
              Container(
                height: 0.5,
                color: AppTheme.surfaceBorder.withValues(alpha: 0.4),
              ),
              Expanded(child: _buildMessageList(s)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double s) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 2 * s,
            height: 12 * s,
            decoration: BoxDecoration(
              color: const Color(0xFFA335EE).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          SizedBox(width: 6 * s),
          Text(
            'COMBAT LOG',
            style: GoogleFonts.rajdhani(
              fontSize: 10 * s,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          // Entry count
          Text(
            '${widget.entries.length}',
            style: GoogleFonts.rajdhani(
              fontSize: 9 * s,
              color: AppTheme.textSecondary.withValues(alpha: 0.35),
            ),
          ),
          SizedBox(width: 8 * s),
          // Scroll to bottom
          GestureDetector(
            onTap: () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            },
            child: Icon(
              Icons.vertical_align_bottom_rounded,
              size: 13 * s,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(width: 6 * s),
          // Collapse button
          GestureDetector(
            onTap: () => setState(() => _isExpanded = false),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16 * s,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(double s) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 8 * s,
        right: 8 * s,
        top: 2 * s,
        bottom: 4 * s,
      ),
      itemCount: widget.entries.length,
      itemExtent: 16 * s, // fixed height for performance
      itemBuilder: (context, index) {
        final entry = widget.entries[index];
        final isSystemMsg = entry.message.startsWith('──') ||
            entry.message.startsWith('══') ||
            entry.message.startsWith('★');

        return Padding(
          padding: EdgeInsets.only(left: isSystemMsg ? 0 : 6 * s),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              entry.message,
              style: GoogleFonts.rajdhani(
                fontSize: isSystemMsg ? 10 * s : 10.5 * s,
                fontWeight: isSystemMsg ? FontWeight.w700 : FontWeight.w500,
                color: entry.color.withValues(
                  alpha: isSystemMsg ? 0.9 : 0.8,
                ),
                height: 1.2,
                letterSpacing: isSystemMsg ? 0.5 : 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
