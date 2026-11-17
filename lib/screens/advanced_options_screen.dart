import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../theme/app_colors.dart';
import '../widgets/hydro_top_bar.dart';
import '../widgets/wave_progress_ring.dart';

class AdvancedOptionsScreen extends StatefulWidget {
  const AdvancedOptionsScreen({super.key});

  @override
  State<AdvancedOptionsScreen> createState() => _AdvancedOptionsScreenState();
}

class _AdvancedOptionsScreenState extends State<AdvancedOptionsScreen> {
  bool _isPinSupported = true;
  bool _isBatteryExempt = true;
  bool _isPrecisionEngineExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkCapabilities();
  }

  Future<void> _checkCapabilities() async {
    final pinSupported = await WidgetService.isPinWidgetSupported();
    final batteryExempt = await NotificationService.isBatteryOptimizationExempt();
    if (mounted) {
      setState(() {
        _isPinSupported = pinSupported;
        _isBatteryExempt = batteryExempt;
      });
    }
  }

  void _onPinWidgetPressed(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final pinned = await WidgetService.requestPinWidget();

    if (context.mounted) {
      messenger.clearSnackBars();
      if (pinned) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Widget pin request sent to your Home Screen launcher!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF1565C0),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        _showManualWidgetInstructions(context);
      }
    }
  }

  void _showManualWidgetInstructions(BuildContext context) {
    final provider = Provider.of<HydrationProvider>(context, listen: false);
    final colors = AppColors(isDark: provider.isDarkMode);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: colors.surfaceBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.cyanAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.widgets_rounded, color: colors.cyanAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add to Home & Lock Screen',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInstructionStep(
                colors,
                stepNumber: '1',
                title: 'Go to your Android Home Screen',
                description: 'Press the Home button to exit to your device home screen.',
              ),
              _buildInstructionStep(
                colors,
                stepNumber: '2',
                title: 'Touch & hold an empty space',
                description: 'Long-press any empty area until the launcher menu pops up, then tap "Widgets".',
              ),
              _buildInstructionStep(
                colors,
                stepNumber: '3',
                title: 'Find Hydro Tracker',
                description: 'Scroll through the widget list, find Hydro Tracker, and drag the sleek widget onto your Home Screen.',
              ),
              _buildInstructionStep(
                colors,
                stepNumber: '4',
                title: 'Lock Screen Access',
                description: 'On devices supporting Lock Screen widgets or Always-On Display, add Hydro Tracker via Lock Screen customization settings.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Got it!',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep(
    AppColors colors, {
    required String stepNumber,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: colors.cyanAccent.withValues(alpha: 0.15),
            child: Text(
              stepNumber,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.cyanAccent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  // Header
                  Text(
                    'Advanced Options',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'System widgets, quick shortcuts, and device integrations',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 1. PRIMARY CARD: Home & Lock Screen Widget Feature Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.surfaceBorder),
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
                        // Card Header Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.cyanAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.widgets_rounded,
                                color: colors.cyanAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Home & Lock Screen Widget',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.cyanAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'QUICK INTAKE ENTRY • ZERO LAUNCH DELAY',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: colors.cyanAccent,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Text(
                          'Add our sleek widget to your Home Screen or Lock Screen. Log water intake in one tap without needing to open the app!',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Sleek Widget Preview Box (as requested: sleek, progress circle without percentage, and options to add intake)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.cardBgAlt,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: colors.cyanAccent.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.cyanAccent.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.preview_rounded, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'LIVE WIDGET PREVIEW',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF10B981),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Inner Sleek Widget layout
                              Row(
                                children: [
                                  // Sleek progress circle WITHOUT showing percentage (as requested)
                                  WaveProgressRing(
                                    progress: provider.progressRatio,
                                    currentMl: provider.todayIntakeMl,
                                    goalMl: provider.dailyGoalMl,
                                    size: 88,
                                    isDark: provider.isDarkMode,
                                    showPercentage: false, // Clean circle, no percentage number
                                  ),

                                  const SizedBox(width: 16),

                                  // Widget Controls: Info + Quick Add Intake Buttons
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${provider.todayIntakeMl} / ${provider.dailyGoalMl} ml',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: colors.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: colors.cyanAccent.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: colors.cyanAccent.withValues(alpha: 0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                '${((provider.todayIntakeMl / (provider.dailyGoalMl > 0 ? provider.dailyGoalMl : 2500)) * 100).toInt().clamp(0, 100)}%',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: colors.cyanAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Quick add intake buttons (Sleek Pills: Glass + 250ml)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildWidgetAddButton(
                                                context: context,
                                                label: provider.hasConfiguredGlass
                                                    ? 'Glass (${provider.customGlassMl}ml)'
                                                    : 'Glass',
                                                amountMl: provider.customGlassMl,
                                                colors: colors,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildWidgetAddButton(
                                                context: context,
                                                label: '+250 ml',
                                                amountMl: 250,
                                                colors: colors,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Action Buttons: Pin to Home Screen + How to Add guide
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                onPressed: _isPinSupported
                                    ? () => _onPinWidgetPressed(context)
                                    : () => _showManualWidgetInstructions(context),
                                icon: const Icon(Icons.add_to_home_screen_rounded, size: 18, color: Colors.white),
                                label: Text(
                                  _isPinSupported ? 'Add to Home Screen' : 'How to Add Widget',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primaryBlue,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: () => _showManualWidgetInstructions(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: colors.cyanAccent.withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  'Instructions',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: colors.cyanAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Collapsible Precision Alarm Engine Diagnostics Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.surfaceBorder),
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
                        // Clickable Accordion Header
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isPrecisionEngineExpanded = !_isPrecisionEngineExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Precision Engine Status',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'exactAllowWhileIdle • Doze mode defense',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _isPrecisionEngineExpanded ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  child: Icon(Icons.expand_more_rounded, color: colors.textSecondary, size: 22),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expanded Diagnostic Matrix
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(height: 1),
                                const SizedBox(height: 14),

                                // Battery Optimization Status
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: colors.cardBgAlt,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Battery Optimization:',
                                          style: GoogleFonts.poppins(fontSize: 12.5, color: colors.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _isBatteryExempt
                                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _isBatteryExempt ? 'EXEMPTED' : 'NOT EXEMPTED',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _isBatteryExempt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // OEM Warning & Action Buttons
                                if (!_isBatteryExempt) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await NotificationService.requestBatteryOptimizationExemption();
                                        _checkCapabilities();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFF97316)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: Text(
                                        'Request Exemption (Unrestricted)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFF97316),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          await NotificationService.openSamsungDeviceCare();
                                        },
                                        icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                                        label: Text(
                                          'Device Care',
                                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: colors.cyanAccent,
                                          side: BorderSide(color: colors.cyanAccent.withValues(alpha: 0.4)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final hasPerm = await NotificationService.requestPermissions();
                                          if (!hasPerm && context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text('Notifications are disabled in Android Settings.'),
                                                backgroundColor: const Color(0xFFEF4444),
                                                action: SnackBarAction(
                                                  label: 'Settings',
                                                  textColor: Colors.white,
                                                  onPressed: () => NotificationService.openNotificationSettings(),
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          final testTime = await NotificationService.scheduleOneMinuteTest();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).clearSnackBars();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  NotificationService.formatAlarmConfirmation(testTime),
                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                                ),
                                                backgroundColor: const Color(0xFF10B981),
                                                behavior: SnackBarBehavior.floating,
                                                duration: const Duration(seconds: 4),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.alarm_rounded, size: 16, color: Colors.white),
                                        label: Text(
                                          'Test 1-Min Alarm',
                                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colors.primaryBlue,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Diagnostic Note
                                Text(
                                  'Uses exactAllowWhileIdle to schedule alarms directly with the Android AlarmManager, bypassing standard Doze mode standby limits.',
                                  style: GoogleFonts.poppins(fontSize: 11, color: colors.textSecondary, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                          crossFadeState: _isPrecisionEngineExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 250),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWidgetAddButton({
    required BuildContext context,
    required String label,
    required int amountMl,
    required AppColors colors,
  }) {
    return InkWell(
      onTap: () {
        final provider = Provider.of<HydrationProvider>(context, listen: false);
        provider.logWater(amountMl);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged $label via Widget Preview!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            backgroundColor: colors.primaryBlue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.surfaceBorder),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
