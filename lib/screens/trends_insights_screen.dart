import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/hydration_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/hydration_ranks_sheet.dart';
import '../widgets/hydro_top_bar.dart';
import '../services/notification_service.dart';

class TrendsInsightsScreen extends StatefulWidget {
  const TrendsInsightsScreen({super.key});

  @override
  State<TrendsInsightsScreen> createState() => _TrendsInsightsScreenState();
}

class _TrendsInsightsScreenState extends State<TrendsInsightsScreen> {
  // Goal Calculator State
  bool _useCm = false;
  final TextEditingController _ftController = TextEditingController();
  final TextEditingController _inController = TextEditingController();
  final TextEditingController _cmController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _gender = 'Male';
  double _pal = 1.75; // Physical activity level (1.4: Sedentary, 1.6: Light, 1.75: Moderate, 2.0: Active, 2.2: Very Active)
  bool _isAthlete = false;
  static const double _tempC = 28.0;
  static const double _humidityPct = 50.0;
  int? _calculatedGoalMl;

  // Accordion Toggles
  bool _isMealsExpanded = false;

  // Monthly Heatmap State
  DateTime _activeHeatmapMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool get _canIncrementHeatmapMonth {
    final now = DateTime.now();
    return _activeHeatmapMonth.year < now.year ||
        (_activeHeatmapMonth.year == now.year && _activeHeatmapMonth.month < now.month);
  }

  void _previousHeatmapMonth() {
    setState(() {
      _activeHeatmapMonth = DateTime(_activeHeatmapMonth.year, _activeHeatmapMonth.month - 1, 1);
    });
  }

  void _nextHeatmapMonth() {
    if (!_canIncrementHeatmapMonth) return;
    setState(() {
      _activeHeatmapMonth = DateTime(_activeHeatmapMonth.year, _activeHeatmapMonth.month + 1, 1);
    });
  }

  // Meal Schedule Controllers
  TimeOfDay _bfastTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<HydrationProvider>(context, listen: false);
    final schedule = provider.mealSchedule;
    _bfastTime = _parseTimeOfDay(schedule['bfast'] ?? '08:30 AM');
    _lunchTime = _parseTimeOfDay(schedule['lunch'] ?? '01:00 PM');
    _dinnerTime = _parseTimeOfDay(schedule['dinner'] ?? '08:00 PM');
  }

  @override
  void dispose() {
    _ftController.dispose();
    _inController.dispose();
    _cmController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _showConfirmationBanner(String message, {Color color = const Color(0xFF1565C0)}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim();
      final isPm = clean.toUpperCase().contains('PM');
      final isAm = clean.toUpperCase().contains('AM');
      final timeOnly = clean.replaceAll(RegExp(r'[A-Za-z]'), '').trim();
      final parts = timeOnly.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 30);
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  void _calculateGoal(HydrationProvider provider) {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final age = int.tryParse(_ageController.text) ?? 0;

    double? heightCm;
    if (_useCm) {
      heightCm = double.tryParse(_cmController.text);
    } else {
      final ft = double.tryParse(_ftController.text) ?? 0.0;
      final inches = double.tryParse(_inController.text) ?? 0.0;
      if (ft > 0 || inches > 0) {
        heightCm = (ft * 30.48) + (inches * 2.54);
      }
    }

    if (weight <= 0) {
      _showConfirmationBanner(
        'Please enter your weight in kg to calculate your goal',
        color: const Color(0xFFD97706),
      );
      return;
    }

    if (age <= 0) {
      _showConfirmationBanner(
        'Please enter your age in years to calculate your goal',
        color: const Color(0xFFD97706),
      );
      return;
    }

    final suggested = provider.calculateSuggestedGoal(
      weightKg: weight,
      age: age,
      gender: _gender,
      pal: _pal,
      isAthlete: _isAthlete,
      tempC: _tempC,
      humidityPct: _humidityPct,
      heightCm: heightCm,
    );

    setState(() {
      _calculatedGoalMl = suggested;
    });

    _showConfirmationBanner(
      'Goal Calculated: ${(suggested / 1000).toStringAsFixed(1)}L ($suggested ml)',
      color: const Color(0xFF1565C0),
    );
  }

  void _resetGoalCalculator() {
    setState(() {
      _ftController.clear();
      _inController.clear();
      _cmController.clear();
      _weightController.clear();
      _ageController.clear();
      _gender = 'Male';
      _pal = 1.75;
      _isAthlete = false;
      _calculatedGoalMl = null;
    });
    _showConfirmationBanner(
      'Calculator values reset',
      color: const Color(0xFFD97706),
    );
  }

  Future<void> _launchScienceReferenceUrl() async {
    final uri = Uri.parse('https://www.gov-online.go.jp/hlj/en/april_2026/april_2026-09.html');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showConfirmationBanner(
          'Could not open browser for reference link',
          color: const Color(0xFFEF4444),
        );
      }
    } catch (e) {
      _showConfirmationBanner(
        'Unable to open link: $e',
        color: const Color(0xFFEF4444),
      );
    }
  }

  void _applyGoal(HydrationProvider provider) async {
    if (_calculatedGoalMl != null) {
      await provider.updateGoal(_calculatedGoalMl!);
      _showConfirmationBanner(
        'Daily Goal set to ${(_calculatedGoalMl! / 1000).toStringAsFixed(1)}L ($_calculatedGoalMl ml)!',
        color: const Color(0xFF10B981),
      );
    }
  }

  void _openRanksModal(BuildContext context, String currentRank) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HydrationRanksSheet(currentRank: currentRank),
    );
  }

  void _confirmDeleteLog(BuildContext context, HydrationProvider provider, int logId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Delete Log Entry?',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove this water intake entry?',
          style: GoogleFonts.poppins(color: const Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteLogById(logId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Log entry deleted',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: const Color(0xFFEF4444),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _selectMealTime(BuildContext context, String mealType) async {
    TimeOfDay initial;
    String mealName;
    if (mealType == 'bfast') {
      initial = _bfastTime;
      mealName = 'Breakfast';
    } else if (mealType == 'lunch') {
      initial = _lunchTime;
      mealName = 'Lunch';
    } else {
      initial = _dinnerTime;
      mealName = 'Dinner';
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      final timeFormatted = _formatTimeOfDay(picked);
      if (!mounted) return;
      setState(() {
        if (mealType == 'bfast') {
          _bfastTime = picked;
        } else if (mealType == 'lunch') {
          _lunchTime = picked;
        } else {
          _dinnerTime = picked;
        }
      });
      _showConfirmationBanner('$mealName time set to $timeFormatted');
    }
  }

  void _saveMeals(HydrationProvider provider) async {
    final bfast = _formatTimeOfDay(_bfastTime);
    final lunch = _formatTimeOfDay(_lunchTime);
    final dinner = _formatTimeOfDay(_dinnerTime);

    await NotificationService.requestPermissions();
    await provider.saveMealSchedule(bfast, lunch, dinner);

    final postBfast = _formatTimeOfDay(TimeOfDay(
      hour: (_bfastTime.hour + (_bfastTime.minute + 30) ~/ 60) % 24,
      minute: (_bfastTime.minute + 30) % 60,
    ));
    final postLunch = _formatTimeOfDay(TimeOfDay(
      hour: (_lunchTime.hour + (_lunchTime.minute + 30) ~/ 60) % 24,
      minute: (_lunchTime.minute + 30) % 60,
    ));
    final postDinner = _formatTimeOfDay(TimeOfDay(
      hour: (_dinnerTime.hour + (_dinnerTime.minute + 30) ~/ 60) % 24,
      minute: (_dinnerTime.minute + 30) % 60,
    ));

    _showConfirmationBanner(
      'Meal schedule saved! Post-meal reminders set: Breakfast at $postBfast, Lunch at $postLunch, Dinner at $postDinner',
      color: const Color(0xFF10B981),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, provider, child) {
        final colors = AppColors(isDark: provider.isDarkMode);
        final isSelectedGoalMet = provider.selectedDateProgressRatio >= 1.0;
        final isTodaySelected = provider.selectedDateString == provider.formatDateString(DateTime.now());

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
                  // Page Header (Without calendar icon)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trends and Insights',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Hydration calculator, history logs & activity heatmap',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 1. Personalized Goal Calculator
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.surfaceBorder),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadowColor,
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Personalized Goal Calculator',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Smart daily target recommendation',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() => _useCm = !_useCm);
                                _showConfirmationBanner(_useCm ? 'Height unit: Centimeters (cm)' : 'Height unit: Feet & Inches (ft/in)');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.secondaryBtnBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colors.secondaryBtnBorder),
                                ),
                                child: Text(
                                  _useCm ? 'Use ft/in' : 'Use cm',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.secondaryBtnText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Height Input
                        Text('Height', style: GoogleFonts.poppins(fontSize: 12, color: colors.textSecondary)),
                        const SizedBox(height: 6),
                        if (_useCm) ...[
                          _buildCalculatorInput(
                            controller: _cmController,
                            hint: 'Height in cm',
                            fieldLabel: 'Height',
                            colors: colors,
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildCalculatorInput(
                                  controller: _ftController,
                                  hint: 'Feet (ft)',
                                  fieldLabel: 'Height Feet',
                                  colors: colors,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildCalculatorInput(
                                  controller: _inController,
                                  hint: 'Inches (in)',
                                  fieldLabel: 'Height Inches',
                                  colors: colors,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Weight & Age Input
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Weight (kg)', style: GoogleFonts.poppins(fontSize: 12, color: colors.textSecondary)),
                                  const SizedBox(height: 6),
                                  _buildCalculatorInput(
                                    controller: _weightController,
                                    hint: 'weight in kg',
                                    fieldLabel: 'Weight',
                                    colors: colors,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Age (yrs)', style: GoogleFonts.poppins(fontSize: 12, color: colors.textSecondary)),
                                  const SizedBox(height: 6),
                                  _buildCalculatorInput(
                                    controller: _ageController,
                                    hint: 'Age in years',
                                    fieldLabel: 'Age',
                                    colors: colors,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Gender Selector
                        Text('Gender', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 6),
                        Row(
                          children: ['Male', 'Female', 'Other'].map((g) {
                            final isSel = _gender == g;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _gender = g);
                                    _showConfirmationBanner('Gender set to $g');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSel ? colors.primaryBlue : colors.secondaryBtnBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSel ? colors.cyanAccent : colors.secondaryBtnBorder,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        g,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                          color: isSel ? Colors.white : colors.secondaryBtnText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),

                        // Physical Activity Level (PAL)
                        Text('Activity Level (PAL)', style: GoogleFonts.poppins(fontSize: 12, color: colors.textSecondary)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.cardBgAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.surfaceBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<double>(
                              value: _pal,
                              isExpanded: true,
                              dropdownColor: colors.cardBg,
                              icon: Icon(Icons.keyboard_arrow_down, color: colors.textSecondary),
                              items: const [
                                DropdownMenuItem(
                                  value: 1.4,
                                  child: Text('Sedentary (1.4 • Desk job, minimal exercise)'),
                                ),
                                DropdownMenuItem(
                                  value: 1.6,
                                  child: Text('Light (1.6 • Light activity 1–3 days/wk)'),
                                ),
                                DropdownMenuItem(
                                  value: 1.75,
                                  child: Text('Moderate (1.75 • Exercise 3–5 days/wk)'),
                                ),
                                DropdownMenuItem(
                                  value: 2.0,
                                  child: Text('Active (2.0 • Daily workout 6–7 days/wk)'),
                                ),
                                DropdownMenuItem(
                                  value: 2.2,
                                  child: Text('Very Active (2.2 • Heavy athletic training)'),
                                ),
                              ],
                              style: GoogleFonts.poppins(
                                color: colors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged: (val) {
                                if (val != null) setState(() => _pal = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Athlete Switch
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.cardBgAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.surfaceBorder),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Competitive / Endurance Athlete',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '+1,070 mL turnover adjustment',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: colors.textSecondary,
                              ),
                            ),
                            value: _isAthlete,
                            activeColor: colors.cyanAccent,
                            onChanged: (val) => setState(() => _isAthlete = val),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Calculate Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _calculateGoal(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.isDark ? const Color(0xFF00E5FF) : colors.primaryBlue,
                              foregroundColor: colors.isDark ? const Color(0xFF0F172A) : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Calculate My Goal',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),

                        // Calculated Result Display + Reset Button
                        if (_calculatedGoalMl != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.cardBgAlt,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Recommended Goal:',
                                      style: GoogleFonts.poppins(fontSize: 12, color: colors.textSecondary),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${(_calculatedGoalMl! / 1000).toStringAsFixed(1)} L ($_calculatedGoalMl ml)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _applyGoal(provider),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          'Apply as Daily Goal',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _resetGoalCalculator,
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          'Reset',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Science citation & clickable reference banner
                        InkWell(
                          onTap: _launchScienceReferenceUrl,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.cardBgAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.cyanAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.science_rounded, size: 16, color: colors.cyanAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Based on the human water turnover model published in Science (Yamada et al., 2022). Calculates direct drinking water intake, subtracting ~20% food moisture. Clamped to safe 1,500 – 4,000 mL bounds. Calibrated for adults (18+); pregnant or nursing individuals should consult a physician.',
                                        style: GoogleFonts.poppins(fontSize: 10, color: colors.textMuted, height: 1.35),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Tap to view research article & details',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: colors.cyanAccent,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.open_in_new_rounded, size: 11, color: colors.cyanAccent),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 2. Goal Status & Perfect Days Row (Beside each other)
                  // ==========================================
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridCard(
                          title: 'Goal Status',
                          value: isSelectedGoalMet ? 'Completed' : 'Incomplete',
                          color: isSelectedGoalMet ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridCard(
                          title: 'Perfect Days',
                          value: '${provider.perfectDaysCount} Days',
                          color: const Color(0xFFF59E0B),
                          colors: colors,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 3. Rank Roadmap and Next Tier Progress (Clickable)
                  // ==========================================
                  InkWell(
                    onTap: () => _openRanksModal(context, provider.currentSelectedRank),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.surfaceBorder),
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
                                ),
                                child: const Icon(Icons.military_tech_rounded, color: Color(0xFF00E5FF), size: 22),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Rank Roadmap',
                                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.info_outline, color: colors.cyanAccent, size: 14),
                                    ],
                                  ),
                                  Text(
                                    'Current: ${provider.currentRankName}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: colors.cyanAccent, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.secondaryBtnBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colors.secondaryBtnBorder),
                                ),
                                child: Text(
                                  'View All',
                                  style: GoogleFonts.poppins(fontSize: 10.5, color: colors.secondaryBtnText, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Next: ${provider.nextRankName}',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
                              ),
                              Text(
                                '${provider.nextRankNeededMl} ml to unlock',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: colors.cyanAccent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: provider.nextRankProgressRatio,
                              minHeight: 10,
                              backgroundColor: colors.emptyComponentBg,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.cyanAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 4. Monthly Activity Heatmap with Month Navigation
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Monthly Activity Heatmap',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'Success: ${provider.successRatePct.toStringAsFixed(0)}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Month Navigation Toolbar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded),
                              color: colors.textPrimary,
                              iconSize: 24,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _previousHeatmapMonth,
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_activeHeatmapMonth),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded),
                              color: _canIncrementHeatmapMonth
                                  ? colors.textPrimary
                                  : colors.textSecondary.withValues(alpha: 0.3),
                              iconSize: 24,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _canIncrementHeatmapMonth ? _nextHeatmapMonth : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Heatmap Tiles Grid (Exact days in active month: 28, 29, 30, or 31)
                        Builder(
                          builder: (context) {
                            final daysInMonth = DateTime(_activeHeatmapMonth.year, _activeHeatmapMonth.month + 1, 0).day;
                            final now = DateTime.now();

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  crossAxisSpacing: 4.5,
                                  mainAxisSpacing: 4.5,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: daysInMonth,
                                itemBuilder: (context, index) {
                                  final day = index + 1;
                                  final date = DateTime(_activeHeatmapMonth.year, _activeHeatmapMonth.month, day);
                                  final dateStr = provider.formatDateString(date);
                                  final total = provider.dailyTotalsMap[dateStr] ?? 0;
                                  final ratio = provider.dailyGoalMl > 0 ? (total / provider.dailyGoalMl) : 0.0;
                                  final isSelected = dateStr == provider.selectedDateString;
                                  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

                                  // Level mapping: Level 0 (0%), Level 1 (1–49%), Level 2 (50–79%), Level 3 (80–99%), Level 4 (100%+)
                                  Color tileColor;
                                  if (ratio >= 1.0) {
                                    tileColor = const Color(0xFF10B981); // 100%+
                                  } else if (ratio >= 0.8) {
                                    tileColor = const Color(0xFF00E5FF); // 80-99%
                                  } else if (ratio >= 0.5) {
                                    tileColor = const Color(0xFF3B82F6); // 50-79%
                                  } else if (ratio > 0) {
                                    tileColor = const Color(0xFFF97316); // 1-49%
                                  } else {
                                    tileColor = colors.emptyComponentBg; // 0%
                                  }

                                  return InkWell(
                                    onTap: () => provider.selectDate(date),
                                    borderRadius: BorderRadius.circular(4),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: tileColor,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isSelected
                                              ? colors.cyanAccent
                                              : (isToday ? colors.cyanAccent : colors.emptyComponentBorder),
                                          width: isSelected ? 1.5 : (isToday ? 1.2 : 0.6),
                                        ),
                                      ),
                                      child: Center(
                                        child: isToday
                                            ? Text(
                                                '$day',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: (ratio == 0 && !colors.isDark) ? colors.textPrimary : Colors.white,
                                                ),
                                              )
                                            : (isSelected
                                                ? Container(
                                                    width: 3,
                                                    height: 3,
                                                    decoration: BoxDecoration(
                                                      color: (ratio == 0 && !colors.isDark) ? colors.cyanAccent : Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  )
                                                : Text(
                                                    '$day',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w500,
                                                      color: ratio > 0 ? Colors.white.withValues(alpha: 0.85) : colors.textSecondary.withValues(alpha: 0.5),
                                                    ),
                                                  )),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        // Heatmap Legend (Level 4: 100%+, Level 3: 80-99%, Level 2: 50-79%, Level 1: 1-49%, Level 0: 0%)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildLegendItem('100%+', const Color(0xFF10B981), colors),
                            _buildLegendItem('80-99%', const Color(0xFF00E5FF), colors),
                            _buildLegendItem('50-79%', const Color(0xFF3B82F6), colors),
                            _buildLegendItem('1-49%', const Color(0xFFF97316), colors),
                            _buildLegendItem('0%', colors.emptyComponentBg, colors),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 5. Timeline Log (Selected Date)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM d, yyyy').format(provider.selectedDate),
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'Intake: ${provider.selectedDateIntakeMl} ml / ${provider.dailyGoalMl} ml (${provider.selectedDateProgressPercentage}%)',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF00E5FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (provider.selectedDateLogs.isEmpty) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  const Icon(Icons.water_drop_outlined, size: 36, color: Color(0xFF00E5FF)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No water intake logged for this date.',
                                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: provider.selectedDateLogs.length,
                            separatorBuilder: (context, index) => Divider(color: colors.surfaceBorder, height: 1),
                            itemBuilder: (context, index) {
                              final log = provider.selectedDateLogs[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colors.secondaryBtnBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: colors.secondaryBtnBorder),
                                      ),
                                      child: Icon(Icons.water_drop_rounded, color: colors.cyanAccent, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${log.amountMl} ml',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('hh:mm a').format(log.timestamp),
                                          style: GoogleFonts.poppins(fontSize: 11, color: colors.textSecondary),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    // Can only delete logs of current day
                                    if (isTodaySelected)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: colors.textSecondary, size: 20),
                                        onPressed: () => _confirmDeleteLog(context, provider, log.id!),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 6. Meal Times Schedule
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.surfaceBorder),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isMealsExpanded = !_isMealsExpanded),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Meal Times Schedule',
                                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                  ),
                                  Text(
                                    'Set times to receive post-meal reminders',
                                    style: GoogleFonts.poppins(fontSize: 11, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Icon(
                                _isMealsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),

                        if (_isMealsExpanded) ...[
                          const SizedBox(height: 16),
                          _buildMealRow(context, 'Breakfast', 'bfast', _bfastTime, colors),
                          _buildMealRow(context, 'Lunch', 'lunch', _lunchTime, colors),
                          _buildMealRow(context, 'Dinner', 'dinner', _dinnerTime, colors),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  onPressed: () => _saveMeals(provider),
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  label: Text(
                                    'Save Schedule',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final success = await NotificationService.showPostMealTestNotification('Lunch');
                                    if (context.mounted) {
                                      if (success) {
                                        _showConfirmationBanner(
                                          'Instant post-meal reminder sent to status bar! 🍽️',
                                          color: const Color(0xFF10B981),
                                        );
                                      } else {
                                        _showConfirmationBanner(
                                          'Notifications are disabled. Enable them in Android settings.',
                                          color: const Color(0xFFEF4444),
                                        );
                                      }
                                    }
                                  },
                                  icon: Icon(Icons.notifications_active_outlined, size: 16, color: colors.cyanAccent),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: colors.cyanAccent),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  label: Text(
                                    'Test Alert',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: colors.cyanAccent, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalculatorInput({
    required TextEditingController controller,
    required String hint,
    required AppColors colors,
    String? fieldLabel,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: GoogleFonts.poppins(color: colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: colors.textMuted, fontSize: 12),
        filled: true,
        fillColor: colors.cardBgAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.surfaceBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.surfaceBorder)),
      ),
      onSubmitted: (val) {
        if (fieldLabel != null && val.trim().isNotEmpty) {
          _showConfirmationBanner('$fieldLabel updated to $val');
        }
      },
    );
  }

  Widget _buildGridCard({
    required String title,
    required String value,
    required Color color,
    required AppColors colors,
    IconData? trailingIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 11, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) Icon(trailingIcon, size: 13, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
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
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: colors.emptyComponentBorder, width: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMealRow(BuildContext context, String label, String key, TimeOfDay time, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: colors.textPrimary)),
          InkWell(
            onTap: () => _selectMealTime(context, key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.cardBgAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.surfaceBorder),
              ),
              child: Text(
                time.format(context),
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: colors.cyanAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
