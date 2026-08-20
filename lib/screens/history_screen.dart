import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../widgets/hydration_ranks_sheet.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, provider, child) {
        final lifetimeL = (provider.lifetimeVolumeMl / 1000).toStringAsFixed(1);
        final isSelectedGoalMet = provider.selectedDateProgressRatio >= 1.0;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activity & History 📅',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Track your hydration stats & activity heatmap',
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

                  // 2. Top Stats Overview Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      // Rank Card (Clickable)
                      InkWell(
                        onTap: () => _openRanksModal(context, provider.currentSelectedRank),
                        borderRadius: BorderRadius.circular(16),
                        child: _buildStatCard(
                          title: '🧜‍♂️ Rank (Selected Date)',
                          value: provider.currentSelectedRank,
                          color: const Color(0xFF00E5FF),
                          trailingIcon: Icons.info_outline,
                        ),
                      ),
                      // Goal Met Card
                      _buildStatCard(
                        title: '🎯 Goal Status',
                        value: isSelectedGoalMet ? '✅ Completed' : '❌ Incomplete',
                        color: isSelectedGoalMet ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      // Lifetime Volume Card
                      _buildStatCard(
                        title: '💧 Lifetime Volume',
                        value: '$lifetimeL L',
                        color: const Color(0xFF3B82F6),
                      ),
                      // Perfect Days Card
                      _buildStatCard(
                        title: '🏆 Perfect Days (100%+)',
                        value: '${provider.perfectDaysCount} Days',
                        color: const Color(0xFFF59E0B),
                      ),
                      // 30-Day Success Rate
                      _buildStatCard(
                        title: '📈 30-Day Success',
                        value: '${provider.successRatePct.toStringAsFixed(0)}%',
                        color: const Color(0xFF8B5CF6),
                      ),
                      // Anti-Wrinkle Shield
                      _buildStatCard(
                        title: '🛡️ Anti-Wrinkle Shield',
                        value: provider.isShieldActive ? 'ACTIVE 🔥' : 'INACTIVE',
                        color: provider.isShieldActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. 30-Day Activity Heatmap Grid
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
                              '🔥 30-Day Activity Heatmap',
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
                        const SizedBox(height: 12),

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

                        const SizedBox(height: 12),

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

                  const SizedBox(height: 24),

                  // 4. Daily Log Timeline Section
                  Text(
                    'Timeline Log (${DateFormat('MMM d, yyyy').format(provider.selectedDate)}) 🕒',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (provider.selectedDateLogs.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('💧', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            'No water logs recorded for this day.',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.selectedDateLogs.length,
                      itemBuilder: (context, index) {
                        final log = provider.selectedDateLogs[index];
                        final timeStr = DateFormat('hh:mm a').format(log.timestamp);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('🥤', style: TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${log.amountMl} ml',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                onPressed: () {
                                  if (log.id != null) {
                                    _confirmDeleteLog(context, provider, log.id!);
                                  }
                                },
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
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    IconData? trailingIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                Icon(trailingIcon, size: 14, color: color),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
