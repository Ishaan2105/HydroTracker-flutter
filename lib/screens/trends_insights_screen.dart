import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../widgets/hydration_ranks_sheet.dart';
import '../widgets/hydro_top_bar.dart';

class TrendsInsightsScreen extends StatefulWidget {
  const TrendsInsightsScreen({super.key});

  @override
  State<TrendsInsightsScreen> createState() => _TrendsInsightsScreenState();
}

class _TrendsInsightsScreenState extends State<TrendsInsightsScreen> {
  // Goal Calculator State (initialized to 0)
  bool _useCm = false;
  final TextEditingController _ftController = TextEditingController(text: '0');
  final TextEditingController _inController = TextEditingController(text: '0');
  final TextEditingController _cmController = TextEditingController(text: '0');
  final TextEditingController _weightController = TextEditingController(text: '0');
  final TextEditingController _ageController = TextEditingController(text: '0');
  String _gender = 'Male';
  int? _calculatedGoalMl;

  // Accordion Toggles
  bool _isMealsExpanded = false;

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
      heightCm = double.tryParse(_cmController.text) ?? 0.0;
    } else {
      final ft = double.tryParse(_ftController.text) ?? 0.0;
      final inches = double.tryParse(_inController.text) ?? 0.0;
      heightCm = (ft * 30.48) + (inches * 2.54);
    }

    if (weight <= 0 && age <= 0 && heightCm <= 0) {
      _showConfirmationBanner(
        'Please enter your height, weight & age to calculate your goal',
        color: const Color(0xFFD97706),
      );
      return;
    }

    final suggested = provider.calculateSuggestedGoal(
      heightCm: heightCm > 0 ? heightCm : 170.0,
      weightKg: weight > 0 ? weight : 70.0,
      age: age > 0 ? age : 25,
      gender: _gender,
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
      _ftController.text = '0';
      _inController.text = '0';
      _cmController.text = '0';
      _weightController.text = '0';
      _ageController.text = '0';
      _gender = 'Male';
      _calculatedGoalMl = null;
    });
    _showConfirmationBanner(
      'Calculator values reset to 0',
      color: const Color(0xFFD97706),
    );
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

    await provider.saveMealSchedule(bfast, lunch, dinner);
    _showConfirmationBanner('Meal times schedule saved successfully!');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, provider, child) {
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
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Hydration calculator, history logs & activity heatmap',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
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
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
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
                                      color: Colors.white,
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
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  _useCm ? 'Use ft/in' : 'Use cm',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00E5FF),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Height Input
                        Text('Height', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 6),
                        if (_useCm) ...[
                          _buildCalculatorInput(
                            controller: _cmController,
                            hint: 'Height in cm (e.g. 175)',
                            fieldLabel: 'Height',
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildCalculatorInput(
                                  controller: _ftController,
                                  hint: 'Feet (ft)',
                                  fieldLabel: 'Height Feet',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildCalculatorInput(
                                  controller: _inController,
                                  hint: 'Inches (in)',
                                  fieldLabel: 'Height Inches',
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
                                  Text('Weight (kg)', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
                                  const SizedBox(height: 6),
                                  _buildCalculatorInput(
                                    controller: _weightController,
                                    hint: 'Weight in kg (e.g. 70)',
                                    fieldLabel: 'Weight',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Age (yrs)', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
                                  const SizedBox(height: 6),
                                  _buildCalculatorInput(
                                    controller: _ageController,
                                    hint: 'Age in years (e.g. 25)',
                                    fieldLabel: 'Age',
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
                                      color: isSel ? const Color(0xFF1565C0) : const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSel ? const Color(0xFF00E5FF) : Colors.white10,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        g,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                          color: isSel ? Colors.white : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Calculate Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _calculateGoal(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
                              foregroundColor: const Color(0xFF0F172A),
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
                              color: const Color(0xFF0F172A),
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
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridCard(
                          title: 'Perfect Days',
                          value: '${provider.perfectDaysCount} Days',
                          color: const Color(0xFFF59E0B),
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
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
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
                                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.info_outline, color: Color(0xFF00E5FF), size: 14),
                                    ],
                                  ),
                                  Text(
                                    'Current: ${provider.currentRankName}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF00E5FF), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  'View All',
                                  style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
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
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                              ),
                              Text(
                                '${provider.nextRankNeededMl} ml to unlock',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF00E5FF)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: provider.nextRankProgressRatio,
                              minHeight: 10,
                              backgroundColor: const Color(0xFF0F172A),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 4. 30-Day Activity Heat Map (Shrunk by 35%)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '30-Day Activity Heatmap',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                        const SizedBox(height: 10),

                        // Heatmap Tiles Grid (Shrunk by 35% with compact horizontal padding and smaller tiles)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              crossAxisSpacing: 4.5,
                              mainAxisSpacing: 4.5,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: 30,
                            itemBuilder: (context, index) {
                              final date = DateTime.now().subtract(Duration(days: 29 - index));
                              final dateStr = provider.formatDateString(date);
                              final total = provider.dailyTotalsMap[dateStr] ?? 0;
                              final ratio = provider.dailyGoalMl > 0 ? (total / provider.dailyGoalMl) : 0.0;
                              final isSelected = dateStr == provider.selectedDateString;
                              final isToday = index == 29;

                              Color tileColor;
                              if (ratio >= 1.0) {
                                tileColor = const Color(0xFF10B981); // 100%+
                              } else if (ratio >= 0.5) {
                                tileColor = const Color(0xFF3B82F6); // 50-99%
                              } else if (ratio > 0) {
                                tileColor = const Color(0xFFF97316); // 1-49%
                              } else {
                                tileColor = const Color(0xFF0F172A); // 0%
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
                                          ? Colors.white
                                          : (isToday ? const Color(0xFF00E5FF) : Colors.white10),
                                      width: isSelected ? 1.5 : (isToday ? 1.2 : 0.6),
                                    ),
                                  ),
                                  child: Center(
                                    child: isToday
                                        ? Text(
                                            '${date.day}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          )
                                        : (isSelected
                                            ? Container(
                                                width: 3,
                                                height: 3,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                              )
                                            : const SizedBox.shrink()),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Heatmap Legend (Compact)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildLegendItem('100%+', const Color(0xFF10B981)),
                            _buildLegendItem('50-99%', const Color(0xFF3B82F6)),
                            _buildLegendItem('1-49%', const Color(0xFFF97316)),
                            _buildLegendItem('0%', const Color(0xFF0F172A)),
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
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
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
                                color: Colors.white,
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
                            separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (context, index) {
                              final log = provider.selectedDateLogs[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.water_drop_rounded, color: Color(0xFF00E5FF), size: 18),
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
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('hh:mm a').format(log.timestamp),
                                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    // Can only delete logs of current day
                                    if (isTodaySelected)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
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
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
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
                                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    'Set times to receive post-meal reminders',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Icon(
                                _isMealsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),

                        if (_isMealsExpanded) ...[
                          const SizedBox(height: 16),
                          _buildMealRow(context, 'Breakfast', 'bfast', _bfastTime),
                          _buildMealRow(context, 'Lunch', 'lunch', _lunchTime),
                          _buildMealRow(context, 'Dinner', 'dinner', _dinnerTime),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _saveMeals(provider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                'Save Schedule',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
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
    String? fieldLabel,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
    IconData? trailingIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
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

  Widget _buildMealRow(BuildContext context, String label, String key, TimeOfDay time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
          InkWell(
            onTap: () => _selectMealTime(context, key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                time.format(context),
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF00E5FF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
