import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/leaderboard_entry.dart';
import '../providers/hydration_provider.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_colors.dart';
import '../widgets/hydro_top_bar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ScrollController _scrollController = ScrollController();
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard({bool isUserRefresh = false}) async {
    if (isUserRefresh) {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<HydrationProvider>(context, listen: false);
      // Ensure local stats are synced to Firestore first
      await CloudSyncService.instance.syncLeaderboardEntry(provider);
      final list = await CloudSyncService.instance.fetchLeaderboardEntries(provider);
      if (mounted) {
        setState(() {
          _entries = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load live standings. Displaying cached ranks.';
        });
      }
    }
  }

  LeaderboardEntry? get _currentUserEntry {
    final user = CloudSyncService.instance.currentUser;
    final currentUid = user?.uid ?? 'local_user';
    try {
      return _entries.firstWhere((e) => e.uid == currentUid);
    } catch (_) {
      return null;
    }
  }

  void _scrollToCurrentUser() {
    final entry = _currentUserEntry;
    if (entry == null || entry.rank <= 3) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Rough offset calculation: podium (~320px) + item height (~74px) * (rank - 4)
    final targetOffset = 300.0 + (entry.rank - 4) * 76.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HydrationProvider>();
    final isDark = provider.isDarkMode;
    final colors = AppColors(isDark: isDark);

    final top3 = _entries.take(3).toList();
    final restOfList = _entries.length > 3 ? _entries.sublist(3) : <LeaderboardEntry>[];
    final userEntry = _currentUserEntry;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top App Bar
                const HydroTopBar(),

                // Sub-header Banner: Live Standings badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.cyanAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.cyanAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Global Community Streaks',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.cyanAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_entries.length} Hydrators',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content with Pull-to-Refresh
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadLeaderboard(isUserRefresh: true),
                    color: colors.cyanAccent,
                    backgroundColor: colors.cardBg,
                    child: _isLoading
                        ? _buildShimmerLoading(colors)
                        : ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            children: [
                              if (_errorMessage != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.amber.shade200),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // 1. Olympic-style Top 3 Podium
                              if (top3.isNotEmpty) _buildPodium(top3, colors),

                              const SizedBox(height: 24),

                              // 2. Section Title: Community Rankings
                              if (restOfList.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Text(
                                      'Challengers',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colors.cardBgAlt,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Ranks #4 – #${_entries.length}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 3. General Rankings List (#4 and below)
                                ...restOfList.map((entry) => _buildRankItem(entry, colors, userEntry?.uid == entry.uid)),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),

            // 4. Sticky Floating "Your Rank" Footer
            if (userEntry != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: _buildStickyUserRankFooter(userEntry, colors),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top-3 Olympic Podium Widget
  // ---------------------------------------------------------------------------
  Widget _buildPodium(List<LeaderboardEntry> top3, AppColors colors) {
    LeaderboardEntry? first = top3.isNotEmpty ? top3[0] : null;
    LeaderboardEntry? second = top3.length > 1 ? top3[1] : null;
    LeaderboardEntry? third = top3.length > 2 ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        color: colors.cardBg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // #2 Silver (Left)
              if (second != null)
                Expanded(
                  child: _buildPodiumPedestal(
                    entry: second,
                    rank: 2,
                    pedestalHeight: 92,
                    avatarRadius: 26,
                    accentColor: const Color(0xFF94A3B8), // Silver
                    gradientColors: [const Color(0xFF64748B), const Color(0xFF334155)],
                    colors: colors,
                  ),
                )
              else
                const Spacer(),

              const SizedBox(width: 10),

              // #1 Gold (Center)
              if (first != null)
                Expanded(
                  child: _buildPodiumPedestal(
                    entry: first,
                    rank: 1,
                    pedestalHeight: 126,
                    avatarRadius: 32,
                    isChampion: true,
                    accentColor: const Color(0xFFFFB800), // Gold
                    gradientColors: [const Color(0xFFF59E0B), const Color(0xFFB45309)],
                    colors: colors,
                  ),
                )
              else
                const Spacer(),

              const SizedBox(width: 10),

              // #3 Bronze (Right)
              if (third != null)
                Expanded(
                  child: _buildPodiumPedestal(
                    entry: third,
                    rank: 3,
                    pedestalHeight: 74,
                    avatarRadius: 24,
                    accentColor: const Color(0xFFCD7F32), // Bronze
                    gradientColors: [const Color(0xFF9A3412), const Color(0xFF7C2D12)],
                    colors: colors,
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPedestal({
    required LeaderboardEntry entry,
    required int rank,
    required double pedestalHeight,
    required double avatarRadius,
    required Color accentColor,
    required List<Color> gradientColors,
    required AppColors colors,
    bool isChampion = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown above #1 Champion
        if (isChampion) ...[
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFFFC107),
            size: 26,
          ),
          const SizedBox(height: 2),
        ],

        // Avatar with Glowing Accent Border
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: isChampion ? 0.45 : 0.25),
                    blurRadius: isChampion ? 16 : 8,
                    spreadRadius: isChampion ? 2 : 0,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: colors.cardBgAlt,
                backgroundImage: (entry.photoUrl != null && entry.photoUrl!.isNotEmpty)
                    ? NetworkImage(entry.photoUrl!)
                    : null,
                child: (entry.photoUrl == null || entry.photoUrl!.isEmpty)
                    ? Text(
                        entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : 'U',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          fontSize: avatarRadius * 0.75,
                        ),
                      )
                    : null,
              ),
            ),

            // Number Medal Pill
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // User Display Name
        Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: isChampion ? 13 : 11.5,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),

        const SizedBox(height: 2),

        // Streak Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text(
                '${entry.currentStreak}d',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 3D-effect Podium Pedestal Block
        Container(
          width: double.infinity,
          height: pedestalHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$rank',
                style: GoogleFonts.poppins(
                  fontSize: isChampion ? 34 : 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: -1,
                ),
              ),
              Text(
                '${(entry.lifetimeVolumeMl / 1000).toStringAsFixed(1)}L',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // General Rankings List Item (#4 and below)
  // ---------------------------------------------------------------------------
  Widget _buildRankItem(LeaderboardEntry entry, AppColors colors, bool isCurrentUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? colors.cyanAccent.withValues(alpha: 0.14)
            : colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? colors.cyanAccent
              : colors.surfaceBorder,
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCurrentUser ? colors.cyanAccent : colors.cardBgAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '#${entry.rank}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? Colors.black : colors.textSecondary,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // User Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.cardBgAlt,
            backgroundImage: (entry.photoUrl != null && entry.photoUrl!.isNotEmpty)
                ? NetworkImage(entry.photoUrl!)
                : null,
            child: (entry.photoUrl == null || entry.photoUrl!.isEmpty)
                ? Text(
                    entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : 'U',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: colors.cyanAccent,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 12),

          // Name and Lifetime Volume
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: colors.cyanAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'YOU',
                          style: GoogleFonts.poppins(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${(entry.lifetimeVolumeMl / 1000).toStringAsFixed(1)} L lifetime volume',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Current Streak Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '${entry.currentStreak} Days',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sticky Floating "Your Rank" Footer
  // ---------------------------------------------------------------------------
  Widget _buildStickyUserRankFooter(LeaderboardEntry userEntry, AppColors colors) {
    return GestureDetector(
      onTap: _scrollToCurrentUser,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.cardBg.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.cyanAccent, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: colors.cyanAccent.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.cyanAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '#${userEntry.rank}',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Profile Avatar
            CircleAvatar(
              radius: 17,
              backgroundColor: colors.cardBgAlt,
              backgroundImage: (userEntry.photoUrl != null && userEntry.photoUrl!.isNotEmpty)
                  ? NetworkImage(userEntry.photoUrl!)
                  : null,
              child: (userEntry.photoUrl == null || userEntry.photoUrl!.isEmpty)
                  ? Text(
                      userEntry.displayName.isNotEmpty ? userEntry.displayName[0].toUpperCase() : 'U',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: colors.cyanAccent,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 10),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your Standing',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    userEntry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Streak Flame
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    '${userEntry.currentStreak}d',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),
            Icon(Icons.arrow_upward_rounded, size: 16, color: colors.cyanAccent),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shimmer Skeleton Loader
  // ---------------------------------------------------------------------------
  Widget _buildShimmerLoading(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: colors.cardBgAlt.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.cyanAccent),
              ),
              const SizedBox(height: 12),
              Text(
                'Retrieving live standings...',
                style: GoogleFonts.poppins(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          5,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 64,
            decoration: BoxDecoration(
              color: colors.cardBgAlt.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
