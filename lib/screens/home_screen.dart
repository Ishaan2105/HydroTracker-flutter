import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../widgets/wave_progress_ring.dart';
import '../widgets/hydro_top_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _logWater(BuildContext context, int amountMl) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<HydrationProvider>(context, listen: false);
    await provider.logWater(amountMl);

    if (mounted) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Added ${amountMl}ml of water!',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1565C0),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _undoLastLog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<HydrationProvider>(context, listen: false);
    final undone = await provider.undoLastLog();

    if (mounted) {
      messenger.clearSnackBars();
      if (undone) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Undone last water log',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'No logs to undo for today',
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _logCustomWater(BuildContext context) {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    final val = int.tryParse(text);
    if (val != null && val > 0) {
      _logWater(context, val);
      _customController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const HydroTopBar(),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Streak Risk Warning Banner (Dynamic)
                  if (provider.isStreakAtRisk) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C2D12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF97316)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFF97316)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'At this pace you might miss your goal today!',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: const Color(0xFFFFEDD5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white70, size: 18),
                            onPressed: () => provider.dismissStreakBanner(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 2. Hero Circular Water Intake Progress Ring
                  Center(
                    child: WaveProgressRing(
                      progress: provider.progressRatio,
                      currentMl: provider.todayIntakeMl,
                      goalMl: provider.dailyGoalMl,
                      size: 240,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 3. Quick Log Section
                  Text(
                    'Quick Log',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Log Buttons in ONE straight horizontal row
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickLogBtn(
                          label: '250 ml',
                          onTap: () => _logWater(context, 250),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickLogBtn(
                          label: '500 ml',
                          onTap: () => _logWater(context, 500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickLogBtn(
                          label: '750 ml',
                          onTap: () => _logWater(context, 750),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickLogBtn(
                          label: '1000 ml',
                          onTap: () => _logWater(context, 1000),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Custom ml Input
                  TextField(
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Custom ml...',
                      hintStyle: GoogleFonts.poppins(
                          color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _logCustomWater(context),
                  ),

                  const SizedBox(height: 10),

                  // Add Button (Border 40% darker)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Material(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _logCustomWater(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6), // 40% darker border
                              width: 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Add',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Undo Last Log Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _undoLastLog(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Undo Last Log',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Current Streak & Best Streak Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Current Streak',
                          value: '${provider.currentStreak} Days',
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Best Streak',
                          value: '${provider.bestStreak} Days',
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 5. 7-Day Hydration Trend (Enhanced Blue UI)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF00E5FF), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '7-Day Hydration Trend',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Daily intake breakdown against target',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Quick Stat Badges Row (All Blue Shades)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DAILY AVG',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(provider.weeklyAverageMl / 1000).toStringAsFixed(1)} L/day',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF00E5FF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL VOLUME',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(provider.weeklyTotalMl / 1000).toStringAsFixed(1)} L',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF38BDF8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TARGET HIT',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(provider.hitRatePct).toStringAsFixed(0)}%',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF60A5FA),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Enhanced Blue Bar Graph Canvas
                        SizedBox(
                          height: 215,
                          child: Stack(
                            children: [
                              // 100% Target Goal Line (Neon Cyan Glow)
                              Positioned(
                                top: 38,
                                left: 0,
                                right: 0,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        '100% Target',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF00E5FF),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        height: 1.2,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                              const Color(0xFF00E5FF).withValues(alpha: 0.1),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 7 Bar Columns (All Blue Gradients)
                              Positioned.fill(
                                top: 50,
                                bottom: 0,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(7, (index) {
                                    final date = DateTime.now().subtract(Duration(days: 6 - index));
                                    final dateStr = DateFormat('yyyy-MM-dd').format(date);
                                    final dayLabel = DateFormat('E').format(date);
                                    final total = provider.dailyTotalsMap[dateStr] ?? 0;
                                    final ratio = provider.dailyGoalMl > 0 ? (total / provider.dailyGoalMl) : 0.0;
                                    final isToday = index == 6;

                                    // Bar height calculation (clamped to max 125px)
                                    final double maxBarHeight = 125.0;
                                    final double barHeight = (ratio.clamp(0.0, 1.2) / 1.0 * (maxBarHeight * 0.85)).clamp(8.0, maxBarHeight);

                                    final isGoalAchieved = ratio >= 1.0;

                                    // All-Blue Gradient Palette
                                    List<Color> barColors;
                                    List<BoxShadow>? barShadow;

                                    if (isGoalAchieved) {
                                      // 100%+ : Electric Neon Cyan to Vivid Ocean Blue
                                      barColors = [const Color(0xFF00E5FF), const Color(0xFF0284C7)];
                                      barShadow = [
                                        BoxShadow(
                                          color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                                          blurRadius: 10,
                                          offset: const Offset(0, -3),
                                        ),
                                      ];
                                    } else if (ratio >= 0.5) {
                                      // 50% - 99% : Sapphire Blue to Deep Royal Blue
                                      barColors = [const Color(0xFF38BDF8), const Color(0xFF1D4ED8)];
                                    } else if (ratio > 0) {
                                      // 1% - 49% : Deep Marine / Cobalt Blue
                                      barColors = [const Color(0xFF2563EB), const Color(0xFF1E3A8A)];
                                    } else {
                                      // 0% : Midnight Slate-Blue
                                      barColors = [const Color(0xFF1E293B), const Color(0xFF0F172A)];
                                    }

                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Amount text above bar
                                        Text(
                                          total > 0 ? '${(total / 1000).toStringAsFixed(1)}L' : '0L',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: isGoalAchieved ? FontWeight.bold : FontWeight.w500,
                                            color: isGoalAchieved ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(height: 6),

                                        // Bar Pillar
                                        Container(
                                          width: 28,
                                          height: barHeight,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: barColors,
                                            ),
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                            border: isToday
                                                ? Border.all(color: Colors.white, width: 1.5)
                                                : Border.all(
                                                    color: isGoalAchieved
                                                        ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                                                        : Colors.white10,
                                                    width: 1,
                                                  ),
                                            boxShadow: barShadow,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Day label badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                                                : const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isToday
                                                  ? const Color(0xFF00E5FF)
                                                  : Colors.white.withValues(alpha: 0.05),
                                            ),
                                          ),
                                          child: Text(
                                            dayLabel,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                              color: isToday ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Chart All-Blue Color Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem('Goal Met (100%+)', const Color(0xFF00E5FF)),
                            const SizedBox(width: 14),
                            _buildLegendItem('50–99%', const Color(0xFF38BDF8)),
                            const SizedBox(width: 14),
                            _buildLegendItem('<50%', const Color(0xFF2563EB)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 6. Weekly Analytics Card
                  // ==========================================
                  _buildWeeklyAnalyticsCard(provider),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 7. Highlights Row: Best Day | Lowest Day | Goal Hit Rate
                  // ==========================================
                  Row(
                    children: [
                      Expanded(
                        child: _buildHighlightCard(
                          title: 'Best Day',
                          value: provider.bestDayLabel,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHighlightCard(
                          title: 'Lowest Day',
                          value: provider.worstDayLabel,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHighlightCard(
                          title: 'Goal Hit Rate',
                          value: '${provider.hitRatePct.toStringAsFixed(0)}%',
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickLogBtn({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildWeeklyAnalyticsCard(HydrationProvider provider) {
    final avgL = (provider.weeklyAverageMl / 1000).toStringAsFixed(2);
    final goalL = (provider.dailyGoalMl / 1000).toStringAsFixed(1);
    final isGoalMetAvg = provider.weeklyAverageMl >= provider.dailyGoalMl;

    String headline;
    String desc;
    Color color;

    if (provider.hitRatePct >= 70) {
      headline = 'Excellent Consistency';
      desc = 'You met your target on ${provider.hitRateFraction} days this week (${provider.hitRatePct.toStringAsFixed(0)}% hit rate). Your body is operating at peak hydration!';
      color = const Color(0xFF10B981);
    } else if (provider.hitRatePct >= 40) {
      headline = 'Steady Hydration Pattern';
      desc = 'You hit your target on ${provider.hitRateFraction} days. Setting post-meal alarms will help you close the gap on quiet days.';
      color = const Color(0xFF00E5FF);
    } else {
      headline = 'Low Intake Alert';
      desc = 'You hit your goal on ${provider.hitRateFraction} days. Try drinking 250ml of water first thing every morning to kickstart your daily target.';
      color = const Color(0xFFF97316);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.insights_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Weekly Analytics',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            headline,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFFCBD5E1),
              height: 1.4,
            ),
          ),
          const Divider(color: Colors.white10, height: 18),
          Row(
            children: [
              Icon(
                isGoalMetAvg ? Icons.trending_up : Icons.trending_down,
                color: isGoalMetAvg ? const Color(0xFF10B981) : const Color(0xFFF97316),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isGoalMetAvg
                      ? 'Weekly avg of $avgL L exceeds your target of $goalL L/day!'
                      : 'Weekly avg is $avgL L/day (target: $goalL L/day).',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
