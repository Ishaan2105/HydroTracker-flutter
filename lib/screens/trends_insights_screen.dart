import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../widgets/hydration_ranks_sheet.dart';

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

  void _pickDate(BuildContext context, HydrationProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await provider.selectDate(picked);
    }
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

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
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
                              'Hydration calculator, history logs & analytics',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF00E5FF), size: 26),
                        onPressed: () => _pickDate(context, provider),
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
                  // 2. Rank & Goal Status Overview 2x2 Grid
                  // ==========================================
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      // Rank (Selected Date)
                      InkWell(
                        onTap: () => _openRanksModal(context, provider.currentSelectedRank),
                        borderRadius: BorderRadius.circular(16),
                        child: _buildGridCard(
                          title: 'Rank (Selected Date)',
                          value: provider.currentSelectedRank,
                          color: const Color(0xFF00E5FF),
                          trailingIcon: Icons.info_outline,
                        ),
                      ),
                      // Goal Status
                      _buildGridCard(
                        title: 'Goal Status',
                        value: isSelectedGoalMet ? 'Completed' : 'Incomplete',
                        color: isSelectedGoalMet ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      // 30-Day Success
                      _buildGridCard(
                        title: '30-Day Success',
                        value: '${provider.successRatePct.toStringAsFixed(0)}%',
                        color: const Color(0xFF8B5CF6),
                      ),
                      // Perfect Days
                      _buildGridCard(
                        title: 'Perfect Days',
                        value: '${provider.perfectDaysCount} Days',
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 3. Rank Roadmap and Next Tier Progress
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
                                Text(
                                  'Rank Roadmap',
                                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                Text(
                                  'Current: ${provider.currentRankName}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF00E5FF), fontWeight: FontWeight.w600),
                                ),
                              ],
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

                  const SizedBox(height: 20),

                  // ==========================================
                  // 4. 30-Day Activity Heat Map
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
                        Row(
                          children: [
                            Text(
                              '30-Day Activity Heatmap',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Tap tile to inspect',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Heatmap Tiles Grid (30 days)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: 30,
                          itemBuilder: (context, index) {
                            final date = DateTime.now().subtract(Duration(days: 29 - index));
                            final dateStr = provider.formatDateString(date);
                            final total = provider.dailyTotalsMap[dateStr] ?? 0;
                            final ratio = provider.dailyGoalMl > 0 ? (total / provider.dailyGoalMl) : 0.0;
                            final isSelected = dateStr == provider.selectedDateString;

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
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: tileColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.white12,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${date.day}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: ratio > 0 || isSelected ? Colors.white : Colors.white38,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // Heatmap Legend
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
                        Row(
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
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelectedGoalMet ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFEF4444).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelectedGoalMet ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                              child: Text(
                                isSelectedGoalMet ? 'Met' : 'Missed',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelectedGoalMet ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
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
                  // 6. 7-Day Hydration Trend (Main Chart)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 18,
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
                                    '7-Day Hydration Trend',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Daily intake breakdown against target',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: const Color(0xFF94A3B8),
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
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
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
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
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
                                        color: const Color(0xFF10B981),
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
                                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
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
                                      provider.hitRateFraction,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF818CF8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Spacious Bar Chart Area
                        Container(
                          height: 200,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Stack(
                            children: [
                              // 100% Target Reference Line
                              Positioned(
                                top: 38,
                                left: 8,
                                right: 8,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '100% Target',
                                        style: GoogleFonts.poppins(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Bar Columns
                              Positioned.fill(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: (provider.sevenDayTrend.isNotEmpty
                                          ? provider.sevenDayTrend
                                          : HydrationProvider.generateDefaultSevenDayTrend())
                                      .map((dayData) {
                                    final ratio = dayData.ratio;
                                    final barHeight = (ratio * 100).clamp(14.0, 115.0);
                                    final isToday = dayData.label == 'Today';

                                    List<Color> gradientColors;
                                    Color glowColor;
                                    if (ratio >= 1.0) {
                                      gradientColors = [const Color(0xFF34D399), const Color(0xFF059669)];
                                      glowColor = const Color(0xFF10B981);
                                    } else if (ratio >= 0.7) {
                                      gradientColors = [const Color(0xFF00E5FF), const Color(0xFF0284C7)];
                                      glowColor = const Color(0xFF00E5FF);
                                    } else if (ratio >= 0.4) {
                                      gradientColors = [const Color(0xFF60A5FA), const Color(0xFF2563EB)];
                                      glowColor = const Color(0xFF3B82F6);
                                    } else {
                                      gradientColors = [const Color(0xFFFBBF24), const Color(0xFFEA580C)];
                                      glowColor = const Color(0xFFEF4444);
                                    }

                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Intake Liters Text
                                        Text(
                                          '${(dayData.totalMl / 1000).toStringAsFixed(1)}L',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                            color: isToday ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(height: 6),

                                        // Capsule Bar
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 500),
                                          width: 22,
                                          height: barHeight,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: gradientColors,
                                            ),
                                            borderRadius: BorderRadius.circular(11),
                                            boxShadow: isToday
                                                ? [
                                                    BoxShadow(
                                                      color: glowColor.withValues(alpha: 0.5),
                                                      blurRadius: 8,
                                                      spreadRadius: 1,
                                                    ),
                                                  ]
                                                : [],
                                            border: isToday
                                                ? Border.all(color: Colors.white, width: 1.5)
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Day Label
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            dayData.label,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                              color: isToday ? const Color(0xFF00E5FF) : const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Chart Color Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendDot(const Color(0xFF10B981), '100%+ Met'),
                            const SizedBox(width: 14),
                            _buildLegendDot(const Color(0xFF00E5FF), '70–99%'),
                            const SizedBox(width: 14),
                            _buildLegendDot(const Color(0xFF3B82F6), '40–69%'),
                            const SizedBox(width: 14),
                            _buildLegendDot(const Color(0xFFEA580C), '<40%'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // 7. 7-Day Hydration Analytics (AI Trend Analysis)
                  // ==========================================
                  _buildTrendAnalysisCard(provider),

                  const SizedBox(height: 16),

                  // ==========================================
                  // 8. Best Day | Lowest Day | Goal Hit Rate
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
                          color: const Color(0xFFF97316),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHighlightCard(
                          title: 'Goal Hit Rate',
                          value: '${provider.hitRateFraction} (${provider.hitRatePct.toStringAsFixed(0)}%)',
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 9. Meal Times Schedule
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
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
              fontSize: 14,
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
          width: 10,
          height: 10,
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

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightCard({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
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

  Widget _buildTrendAnalysisCard(HydrationProvider provider) {
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 18),
              const SizedBox(width: 8),
              Text(
                '7-Day Hydration Analytics',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: const Color(0xFFCBD5E1),
              height: 1.4,
            ),
          ),
          const Divider(color: Colors.white10, height: 16),
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
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.star_outline_rounded, color: Color(0xFFEAB308), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Peak day: ${provider.bestDayLabel} • Lowest day: ${provider.worstDayLabel}.',
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
