import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/wave_progress_ring.dart';
import '../widgets/hydro_top_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _customController = TextEditingController();
  bool _isWeeklyAnalyticsExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetService.init();
    WidgetService.onWidgetActionReceived = (action) {
      if (action == 'create_glass') {
        _triggerGlassCreation();
      }
    };
    NotificationService.onGlassCreationRequested = () {
      if (mounted) {
        _triggerGlassCreation();
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.requestPermissions();
      _checkWidgetLaunchIntent();
      _checkPendingGlassCreation();
    });
  }

  void _triggerGlassCreation() {
    if (!mounted) return;
    final provider = Provider.of<HydrationProvider>(context, listen: false);
    final colors = AppColors(isDark: Theme.of(context).brightness == Brightness.dark);
    _showGlassTrackerModal(context, provider, colors);
  }

  void _checkPendingGlassCreation() {
    if (NotificationService.pendingGlassCreation && mounted) {
      NotificationService.pendingGlassCreation = false;
      _triggerGlassCreation();
    }
  }

  Future<void> _checkWidgetLaunchIntent() async {
    final action = await WidgetService.getInitialAction();
    if (action == 'create_glass' && mounted) {
      _triggerGlassCreation();
    }
  }

  @override
  void dispose() {
    WidgetService.onWidgetActionReceived = null;
    NotificationService.onGlassCreationRequested = null;
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

  void _showGlassTrackerModal(BuildContext context, HydrationProvider provider, AppColors colors) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GlassTrackerSheet(provider: provider, colors: colors),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, provider, child) {
        final colors = AppColors(isDark: provider.isDarkMode);

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
                      isDark: provider.isDarkMode,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 3. Quick Log Section
                  Text(
                    'Quick Log',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
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
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickLogBtn(
                          label: '500 ml',
                          onTap: () => _logWater(context, 500),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickLogBtn(
                          label: '750 ml',
                          onTap: () => _logWater(context, 750),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickLogBtn(
                          label: '1000 ml',
                          onTap: () => _logWater(context, 1000),
                          colors: colors,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Glass Tracker & Custom ml Input Row (Glass on Left, Custom mL on Right)
                  Row(
                    children: [
                      // Create Glass / Glass Tracker Button (Position 1 - Left)
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 48,
                          child: Material(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => _showGlassTrackerModal(context, provider, colors),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: provider.hasConfiguredGlass
                                        ? colors.surfaceBorder
                                        : colors.cyanAccent.withValues(alpha: 0.6),
                                    width: provider.hasConfiguredGlass ? 1.0 : 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      provider.hasConfiguredGlass
                                          ? Icons.local_drink_rounded
                                          : Icons.add_circle_outline_rounded,
                                      color: colors.cyanAccent,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        provider.hasConfiguredGlass
                                            ? 'Glass (${provider.customGlassMl}ml)'
                                            : 'Create Glass',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: provider.hasConfiguredGlass
                                              ? colors.textPrimary
                                              : colors.cyanAccent,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Custom ml Input with embedded submit icon (Position 2 - Right)
                      Expanded(
                        flex: 6,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.surfaceBorder),
                          ),
                          child: TextField(
                            controller: _customController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(
                              color: colors.textPrimary,
                              fontSize: 13.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Custom ml...',
                              hintStyle: GoogleFonts.poppins(
                                color: colors.textMuted,
                                fontSize: 12.5,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(
                                left: 14,
                                right: 4,
                                top: 12,
                                bottom: 12,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.check_circle_rounded,
                                  color: colors.cyanAccent,
                                  size: 22,
                                ),
                                tooltip: 'Log custom ml',
                                onPressed: () => _logCustomWater(context),
                              ),
                            ),
                            onSubmitted: (_) => _logCustomWater(context),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Undo Last Log Button (Matching Primary Card Button UI)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Material(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _undoLastLog(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.surfaceBorder,
                              width: 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.undo_rounded,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Undo Last Log',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Best Streak',
                          value: '${provider.bestStreak} Days',
                          color: const Color(0xFF00E5FF),
                          colors: colors,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 5. 7-Day Hydration Trend (Aesthetic Capsule Glass UI)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : colors.surfaceBorder,
                        width: 1.2,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors.isDark
                            ? [
                                const Color(0xFF131D30),
                                const Color(0xFF0F172A),
                              ]
                            : [
                                Colors.white,
                                const Color(0xFFF0F9FF),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadowColor,
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                        if (colors.isDark)
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.04),
                            blurRadius: 28,
                            offset: const Offset(0, -2),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                              ),
                              child: const Icon(Icons.auto_graph_rounded, color: Color(0xFF00E5FF), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '7-Day Hydration Trend',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Daily intake breakdown against target',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF00E5FF)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${provider.hitRatePct.toStringAsFixed(0)}% Hit',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF00E5FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Quick Stat Badges Row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: colors.statBadgeBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: colors.statBadgeBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.water_drop_rounded, size: 11, color: colors.cyanAccent),
                                        const SizedBox(width: 4),
                                        Text(
                                          'DAILY AVG',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${(provider.weeklyAverageMl / 1000).toStringAsFixed(1)} L/day',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: colors.cyanAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: colors.statBadgeBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: colors.statBadgeBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.waves_rounded, size: 11, color: Color(0xFF38BDF8)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'TOTAL',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: colors.statBadgeBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: colors.statBadgeBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.verified_rounded, size: 11, color: Color(0xFF60A5FA)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'STREAK',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${provider.currentStreak} ${provider.currentStreak == 1 ? "day" : "days"}',
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
                        const SizedBox(height: 20),

                        // Minimalist Rectangular Bar Graph Canvas (No background tracks, no 100% target line, no glow)
                        Container(
                          height: 195,
                          padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                          decoration: BoxDecoration(
                            color: colors.isDark
                                ? const Color(0xFF0B1322).withValues(alpha: 0.6)
                                : const Color(0xFFF1F5F9).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colors.isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04),
                            ),
                          ),
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
                              final isGoalAchieved = ratio >= 1.0;

                              const double maxBarHeight = 110.0;
                              final double barHeight = (ratio.clamp(0.0, 1.0) * maxBarHeight).clamp(0.0, maxBarHeight);

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Top value indicator
                                  SizedBox(
                                    height: 18,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isGoalAchieved) ...[
                                          const Icon(Icons.star_rounded, size: 10, color: Color(0xFF00E5FF)),
                                          const SizedBox(width: 1),
                                        ],
                                        Text(
                                          total > 0 ? '${(total / 1000).toStringAsFixed(1)}L' : '0L',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: isGoalAchieved ? FontWeight.bold : FontWeight.w500,
                                            color: isGoalAchieved
                                                ? const Color(0xFF00E5FF)
                                                : (isToday ? colors.textPrimary : colors.textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Clean Rectangular Bar (Zero background track, zero glow)
                                  SizedBox(
                                    width: 24,
                                    height: maxBarHeight,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: total > 0
                                          ? Container(
                                              width: 24,
                                              height: barHeight.clamp(3.0, maxBarHeight),
                                              decoration: BoxDecoration(
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: isToday
                                                      ? const [Color(0xFF00E5FF), Color(0xFF0284C7)]
                                                      : (isGoalAchieved
                                                          ? const [Color(0xFF00E5FF), Color(0xFF1565C0)]
                                                          : const [Color(0xFF38BDF8), Color(0xFF1E40AF)]),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 24,
                                              height: 1.5,
                                              decoration: BoxDecoration(
                                                color: colors.isDark ? Colors.white24 : Colors.black12,
                                                borderRadius: BorderRadius.circular(1),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Day Label Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isToday
                                          ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                                          : colors.dayBadgeBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isToday
                                            ? const Color(0xFF00E5FF)
                                            : colors.dayBadgeBorder,
                                        width: isToday ? 1.2 : 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      isToday ? 'TODAY' : dayLabel,
                                      style: GoogleFonts.poppins(
                                        fontSize: isToday ? 9.5 : 10.5,
                                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                        color: isToday ? const Color(0xFF00E5FF) : colors.dayBadgeText,
                                        letterSpacing: isToday ? 0.3 : 0.0,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Chart All-Blue Color Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem('Goal Met (100%+)', const Color(0xFF00E5FF), colors),
                            const SizedBox(width: 14),
                            _buildLegendItem('50–99%', const Color(0xFF38BDF8), colors),
                            const SizedBox(width: 14),
                            _buildLegendItem('<50%', const Color(0xFF2563EB), colors),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 6. Weekly Analytics Card
                  // ==========================================
                  _buildWeeklyAnalyticsCard(provider, colors),

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
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHighlightCard(
                          title: 'Lowest Day',
                          value: provider.worstDayLabel,
                          color: const Color(0xFFEF4444),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHighlightCard(
                          title: 'Goal Hit Rate',
                          value: '${provider.hitRatePct.toStringAsFixed(0)}%',
                          color: const Color(0xFF00E5FF),
                          colors: colors,
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
    required AppColors colors,
  }) {
    return Material(
      color: colors.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: colors.shadowColor,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
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
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: colors.textSecondary,
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
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: colors.textSecondary,
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

  Widget _buildLegendItem(String label, Color color, AppColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyAnalyticsCard(HydrationProvider provider, AppColors colors) {
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
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                  color: colors.textPrimary,
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
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          Divider(color: colors.surfaceBorder, height: 18),
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
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Deep-Dive Weekly Analytics Expandable Trigger
          InkWell(
            onTap: () {
              setState(() {
                _isWeeklyAnalyticsExpanded = !_isWeeklyAnalyticsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: colors.statBadgeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.statBadgeBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 16, color: colors.cyanAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detailed Weekly Analytics',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isWeeklyAnalyticsExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(Icons.expand_more_rounded, size: 18, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Body: 6 Detailed Metrics
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.cardBgAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.surfaceBorder),
              ),
              child: Column(
                children: [
                  // Metric 1: Total Volume Consumed
                  _buildAnalyticsRow(
                    icon: Icons.water_drop_rounded,
                    label: 'Total Volume Consumed',
                    value: '${(provider.weeklyTotalMl / 1000).toStringAsFixed(2)} L / ${NumberFormat('#,###').format(provider.weeklyTotalMl)} mL',
                    colors: colors,
                  ),
                  const Divider(height: 14),

                  // Metric 2: Daily Average Intake vs Goal
                  _buildAnalyticsRow(
                    icon: Icons.av_timer_rounded,
                    label: 'Daily Average Intake',
                    value: '${provider.weeklyAverageMl.round()} mL/day (${(provider.dailyGoalMl > 0 ? (provider.weeklyAverageMl / provider.dailyGoalMl * 100).round() : 0)}% of goal)',
                    colors: colors,
                  ),
                  const Divider(height: 14),

                  // Metric 3: Goal Consistency Rate
                  _buildAnalyticsRow(
                    icon: Icons.task_alt_rounded,
                    label: 'Goal Consistency Rate',
                    value: '${provider.hitRateFraction} days (${provider.hitRatePct.toStringAsFixed(0)}%)',
                    colors: colors,
                  ),
                  const Divider(height: 14),

                  // Metric 4: Intake Breakdown by Time of Day
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: colors.cyanAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Time of Day Breakdown',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDiurnalChip('Morning', '06-12', provider.morningIntakeMl, provider.weeklyTotalMl, const Color(0xFFF59E0B), colors),
                          const SizedBox(width: 6),
                          _buildDiurnalChip('Afternoon', '12-18', provider.afternoonIntakeMl, provider.weeklyTotalMl, const Color(0xFF00E5FF), colors),
                          const SizedBox(width: 6),
                          _buildDiurnalChip('Evening', '18-24', provider.eveningIntakeMl, provider.weeklyTotalMl, const Color(0xFF8B5CF6), colors),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 14),

                  // Metric 5: Peak & Lowest Days
                  _buildAnalyticsRow(
                    icon: Icons.swap_vert_rounded,
                    label: 'Peak / Lowest Intake Days',
                    value: 'Peak: ${provider.bestDayLabel}\nLowest: ${provider.worstDayLabel}',
                    colors: colors,
                  ),
                  const Divider(height: 14),

                  // Metric 6: Streak Contribution
                  _buildAnalyticsRow(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Streak Contribution',
                    value: '+${provider.sevenDayTrend.where((d) => d.ratio >= 1.0).length} streak days in rolling 7-day window',
                    colors: colors,
                  ),
                ],
              ),
            ),
            crossFadeState: _isWeeklyAnalyticsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow({
    required IconData icon,
    required String label,
    required String value,
    required AppColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colors.cyanAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: colors.cyanAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiurnalChip(
    String period,
    String timeRange,
    int amountMl,
    int totalWeeklyMl,
    Color accentColor,
    AppColors colors,
  ) {
    final pct = totalWeeklyMl > 0 ? ((amountMl / totalWeeklyMl) * 100).round() : 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              period,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
            Text(
              timeRange,
              style: GoogleFonts.poppins(
                fontSize: 8.5,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${(amountMl / 1000).toStringAsFixed(1)}L',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            Text(
              '$pct%',
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassTrackerSheet extends StatefulWidget {
  final HydrationProvider provider;
  final AppColors colors;

  const _GlassTrackerSheet({required this.provider, required this.colors});

  @override
  State<_GlassTrackerSheet> createState() => _GlassTrackerSheetState();
}

class _GlassTrackerSheetState extends State<_GlassTrackerSheet> {
  int _glassCount = 1;
  late int _selectedGlassMl;
  bool _isCustomizingSize = false;
  final List<int> _sizePresets = [150, 200, 250, 300, 350, 500];
  final TextEditingController _customSizeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedGlassMl = widget.provider.customGlassMl;
    _customSizeController.text = '$_selectedGlassMl';
    _isCustomizingSize = !widget.provider.hasConfiguredGlass;
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  void _logGlasses() async {
    final messenger = ScaffoldMessenger.of(context);
    final count = _glassCount;
    final parsed = int.tryParse(_customSizeController.text.trim()) ?? _selectedGlassMl;
    final glassSize = parsed.clamp(50, 1000);
    final total = count * glassSize;

    HapticFeedback.mediumImpact();
    Navigator.pop(context);

    // If glass size was changed or not configured yet, update persistent preference
    if (glassSize != widget.provider.customGlassMl || !widget.provider.hasConfiguredGlass) {
      await widget.provider.setCustomGlassMl(glassSize);
    }

    await widget.provider.logGlasses(count);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Logged $count ${count == 1 ? "glass" : "glasses"} (${total}ml)! 💧',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final totalMl = _glassCount * _selectedGlassMl;
    final totalL = (totalMl / 1000).toStringAsFixed(2);

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colors.surfaceBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.cyanAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.provider.hasConfiguredGlass
                      ? Icons.local_drink_rounded
                      : Icons.tune_rounded,
                  color: colors.cyanAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.provider.hasConfiguredGlass
                          ? 'Glass Intake Tracker'
                          : 'Set Your Glass Size',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.provider.hasConfiguredGlass
                          ? 'Log water by glasses drunk'
                          : 'Choose your preferred glass capacity',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.provider.hasConfiguredGlass)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isCustomizingSize = !_isCustomizingSize;
                    });
                  },
                  icon: Icon(
                    _isCustomizingSize ? Icons.check_circle_outline : Icons.tune_rounded,
                    size: 16,
                    color: colors.cyanAccent,
                  ),
                  label: Text(
                    _isCustomizingSize ? 'Done' : 'Glass Size',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.cyanAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Glass Size Configurator (if active)
          if (_isCustomizingSize) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.cardBgAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !widget.provider.hasConfiguredGlass
                      ? colors.cyanAccent.withValues(alpha: 0.4)
                      : colors.surfaceBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1 Glass Capacity',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.cyanAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_selectedGlassMl ml',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.cyanAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick a common size or enter a custom amount (50 - 1000 ml):',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sizePresets.map((size) {
                      final isSelected = size == _selectedGlassMl;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedGlassMl = size;
                            _customSizeController.text = '$size';
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.cyanAccent.withValues(alpha: 0.2)
                                : colors.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? colors.cyanAccent : colors.surfaceBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Text(
                            '$size ml',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? colors.cyanAccent : colors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Custom ml input & Set Size button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.surfaceBorder),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _customSizeController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Custom ml',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                              suffixText: 'ml',
                              suffixStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.cyanAccent,
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed >= 50 && parsed <= 1000) {
                                setState(() => _selectedGlassMl = parsed);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final parsed = int.tryParse(_customSizeController.text.trim()) ?? _selectedGlassMl;
                          final clamped = parsed.clamp(50, 1000);
                          HapticFeedback.mediumImpact();
                          await widget.provider.setCustomGlassMl(clamped);
                          if (mounted) {
                            setState(() {
                              _selectedGlassMl = clamped;
                              _isCustomizingSize = false;
                            });
                          }
                          messenger.clearSnackBars();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Glass size set to ${clamped}ml! 🥛',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: const Color(0xFF0284C7),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.cyanAccent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Set Size',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (!_isCustomizingSize && widget.provider.hasConfiguredGlass) ...[
            InkWell(
              onTap: () {
                setState(() => _isCustomizingSize = true);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.cyanAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.cyanAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_drink_rounded, size: 16, color: colors.cyanAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Glass Size: ${_selectedGlassMl}ml',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.cyanAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.cyanAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 11, color: colors.cyanAccent),
                          const SizedBox(width: 3),
                          Text(
                            'Edit',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: colors.cyanAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Counter Stepper Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colors.cardBgAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.surfaceBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Minus button
                    InkWell(
                      onTap: _glassCount > 1
                          ? () {
                              HapticFeedback.lightImpact();
                              setState(() => _glassCount--);
                            }
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.surfaceBorder),
                        ),
                        child: Icon(
                          Icons.remove_rounded,
                          color: _glassCount > 1 ? colors.textPrimary : colors.textMuted,
                          size: 20,
                        ),
                      ),
                    ),

                    // Number of glasses display
                    Column(
                      children: [
                        Text(
                          '$_glassCount',
                          style: GoogleFonts.poppins(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          _glassCount == 1 ? 'Glass' : 'Glasses',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.cyanAccent,
                          ),
                        ),
                      ],
                    ),

                    // Plus button
                    InkWell(
                      onTap: _glassCount < 20
                          ? () {
                              HapticFeedback.lightImpact();
                              setState(() => _glassCount++);
                            }
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.surfaceBorder),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: _glassCount < 20 ? colors.textPrimary : colors.textMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: colors.surfaceBorder, height: 1),
                const SizedBox(height: 12),
                // Live Calculation Preview
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calculate_outlined, size: 15, color: colors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      '$_glassCount × ${_selectedGlassMl}ml = ',
                      style: GoogleFonts.poppins(fontSize: 13, color: colors.textSecondary),
                    ),
                    Text(
                      '$totalMl ml ($totalL L)',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: colors.cyanAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Log Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _logGlasses,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.cyanAccent,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'Log $_glassCount ${_glassCount == 1 ? "Glass" : "Glasses"} ($totalMl ml)',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
