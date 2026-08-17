import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  // Goal Calculator State
  bool _useCm = false;
  final TextEditingController _ftController = TextEditingController(text: '5');
  final TextEditingController _inController = TextEditingController(text: '9');
  final TextEditingController _cmController = TextEditingController(text: '175');
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _ageController = TextEditingController(text: '25');
  String _gender = 'Male';
  int? _calculatedGoalMl;

  // Accordion Toggles
  bool _isReviewExpanded = false;
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
    final weight = double.tryParse(_weightController.text) ?? 70.0;
    final age = int.tryParse(_ageController.text) ?? 25;

    double? heightCm;
    if (_useCm) {
      heightCm = double.tryParse(_cmController.text) ?? 175.0;
    } else {
      final ft = double.tryParse(_ftController.text) ?? 5.0;
      final inches = double.tryParse(_inController.text) ?? 9.0;
      heightCm = (ft * 30.48) + (inches * 2.54);
    }

    final suggested = provider.calculateSuggestedGoal(
      heightCm: heightCm,
      weightKg: weight,
      age: age,
      gender: _gender,
    );

    setState(() {
      _calculatedGoalMl = suggested;
    });
  }

  void _applyGoal(HydrationProvider provider) async {
    if (_calculatedGoalMl != null) {
      await provider.updateGoal(_calculatedGoalMl!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎯 Daily Goal set to $_calculatedGoalMl ml!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF1565C0),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _selectMealTime(BuildContext context, String mealType) async {
    TimeOfDay initial;
    if (mealType == 'bfast') {
      initial = _bfastTime;
    } else if (mealType == 'lunch') {
      initial = _lunchTime;
    } else {
      initial = _dinnerTime;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      setState(() {
        if (mealType == 'bfast') {
          _bfastTime = picked;
        } else if (mealType == 'lunch') {
          _lunchTime = picked;
        } else {
          _dinnerTime = picked;
        }
      });
    }
  }

  void _saveMeals(HydrationProvider provider) async {
    final bfast = _formatTimeOfDay(_bfastTime);
    final lunch = _formatTimeOfDay(_lunchTime);
    final dinner = _formatTimeOfDay(_dinnerTime);

    await provider.saveMealSchedule(bfast, lunch, dinner);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🍽️ Meal Schedule Saved ($bfast, $lunch, $dinner)!',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B1329),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header
                  Text(
                    'Health Insights 💡',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Personalized goal calculator & weekly performance analytics',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. ⚖️ Personalized Goal Calculator Card
                  Container(
                    padding: const EdgeInsets.all(16),
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
                              '⚖️ Personalized Goal Calculator',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            DropdownButton<bool>(
                              value: _useCm,
                              dropdownColor: const Color(0xFF0F172A),
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
                              style: GoogleFonts.poppins(color: const Color(0xFF00E5FF), fontSize: 12),
                              items: const [
                                DropdownMenuItem(value: false, child: Text('ft + in')),
                                DropdownMenuItem(value: true, child: Text('cm')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _useCm = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Inputs Grid (Height, Weight, Age, Gender)
                        Row(
                          children: [
                            // Height Input
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _useCm ? 'Height (cm)' : 'Height (ft/in)',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_useCm) ...[
                                    _buildNumberInput(_cmController, '175'),
                                  ] else ...[
                                    Row(
                                      children: [
                                        Expanded(child: _buildNumberInput(_ftController, 'ft')),
                                        const SizedBox(width: 4),
                                        Expanded(child: _buildNumberInput(_inController, 'in')),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Weight Input
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weight (kg)',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildNumberInput(_weightController, '70'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            // Age Input
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Age (yrs)',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildNumberInput(_ageController, '25'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Gender Dropdown
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gender',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _gender,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF0F172A),
                                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                                        items: const [
                                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _gender = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _calculateGoal(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Calculate My Goal',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),

                        if (_calculatedGoalMl != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Suggested Daily Intake:',
                                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                                ),
                                Text(
                                  '${(_calculatedGoalMl! / 1000).toStringAsFixed(1)} L ($_calculatedGoalMl ml)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00E5FF),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () => _applyGoal(provider),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(
                                    'Set as My Goal',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. 🚀 Rank Roadmap & Next Tier Progress Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🚀 Rank Roadmap & Next Tier Progress',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Track your daily intake progress towards unlocking the next rank tier!',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('🧜‍♂️', style: TextStyle(fontSize: 24)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CURRENT RANK',
                                  style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  provider.currentRankName,
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                              'Next Tier: ${provider.nextRankName}',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF00E5FF)),
                            ),
                            Text(
                              '${provider.nextRankNeededMl} ml needed',
                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
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

                  // 4. 📈 7-Day Trend Chart Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📈 7-Day Hydration Trend',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Custom Bar Chart
                        SizedBox(
                          height: 140,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: provider.sevenDayTrend.map((dayData) {
                              final barHeight = (dayData.ratio * 100).clamp(10.0, 100.0);
                              Color barColor = const Color(0xFF3B82F6);
                              if (dayData.ratio >= 1.0) {
                                barColor = const Color(0xFF10B981);
                              } else if (dayData.ratio < 0.4) {
                                barColor = const Color(0xFFF97316);
                              }

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(dayData.totalMl / 1000).toStringAsFixed(1)}L',
                                    style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    width: 16,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dayData.label,
                                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                        // AI Trend Analysis Card
                        _buildTrendAnalysisCard(provider),

                        const SizedBox(height: 14),

                        // Collapsible Weekly Performance Review
                        InkWell(
                          onTap: () => setState(() => _isReviewExpanded = !_isReviewExpanded),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Text(
                                  '📊 Weekly Performance Review',
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF00E5FF)),
                                ),
                                const Spacer(),
                                Icon(
                                  _isReviewExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: const Color(0xFF00E5FF),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_isReviewExpanded) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildReviewRow('Weekly Average', '${(provider.weeklyAverageMl / 1000).toStringAsFixed(2)} L / day'),
                                _buildReviewRow('Total Volume', '${(provider.weeklyTotalMl / 1000).toStringAsFixed(1)} L'),
                                _buildReviewRow('Best Day', provider.bestDayLabel),
                                _buildReviewRow('Worst Day', provider.worstDayLabel),
                                _buildReviewRow('Goal Hit Rate', provider.hitRateFraction),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. 📅 Best & Worst Day + Goal Hit Rate Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoBox(
                          title: '🏆 Best Day',
                          value: provider.bestDayLabel,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoBox(
                          title: '🎯 Goal Hit Rate',
                          value: '${provider.hitRateFraction} (${provider.hitRatePct.toStringAsFixed(0)}%)',
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 6. 🍽️ Meal Times Schedule (Collapsible Accordion)
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
                                    '🍽️ Meal Times Schedule',
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
                          _buildMealRow(context, '🍳 Breakfast', 'bfast', _bfastTime),
                          _buildMealRow(context, '🥗 Lunch', 'lunch', _lunchTime),
                          _buildMealRow(context, '🍽️ Dinner', 'dinner', _dinnerTime),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberInput(TextEditingController controller, String hint) {
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
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
          Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildInfoBox({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
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
      headline = '🌟 Excellent Consistency!';
      desc = 'You met your target on ${provider.hitRateFraction} days this week (${provider.hitRatePct.toStringAsFixed(0)}% hit rate). Your body is operating at peak hydration!';
      color = const Color(0xFF10B981);
    } else if (provider.hitRatePct >= 40) {
      headline = '👍 Steady Hydration Pattern';
      desc = 'You hit your target on ${provider.hitRateFraction} days. Setting post-meal alarms will help you close the gap on quiet days.';
      color = const Color(0xFF00E5FF);
    } else {
      headline = '⚠️ Low Intake Alert';
      desc = 'You hit your goal on ${provider.hitRateFraction} days. Try drinking 250ml of water first thing every morning to kickstart your daily target.';
      color = const Color(0xFFF97316);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                '7-Day AI Trend Analysis',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
