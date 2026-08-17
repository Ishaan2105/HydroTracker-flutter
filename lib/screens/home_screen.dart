import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../widgets/wave_progress_ring.dart';
import '../widgets/hydration_coach_sheet.dart';

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
          content: Row(
            children: [
              const Text('💧 ', style: TextStyle(fontSize: 18)),
              Text(
                'Added ${amountMl}ml of water!',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
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
              '↩️ Undone last water log',
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

  void _openCoachSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HydrationCoachSheet(),
    );
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
                  // 1. Top Header Bar
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF1565C0),
                        child: Text(
                          provider.userName.isNotEmpty
                              ? provider.userName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${provider.userName} 👋',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Daily Target: ${provider.dailyGoalMl} ml',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Streak Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text(
                              '${provider.currentStreak} Days',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2. Streak Risk Warning Banner (Dynamic)
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
                          const Text('⚠️', style: TextStyle(fontSize: 20)),
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

                  // 3. Hero Circular Water Intake Progress Ring
                  Center(
                    child: WaveProgressRing(
                      progress: provider.progressRatio,
                      currentMl: provider.todayIntakeMl,
                      goalMl: provider.dailyGoalMl,
                      size: 240,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 4. Quick Log Section
                  Text(
                    'Quick Log ⏱️',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Log Buttons Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.5,
                    children: [
                      _buildQuickLogBtn(
                        label: '250ml 🥛',
                        onTap: () => _logWater(context, 250),
                      ),
                      _buildQuickLogBtn(
                        label: '500ml 🥤',
                        onTap: () => _logWater(context, 500),
                      ),
                      _buildQuickLogBtn(
                        label: '750ml 🍶',
                        onTap: () => _logWater(context, 750),
                      ),
                      _buildQuickLogBtn(
                        label: '1000ml 💧',
                        onTap: () => _logWater(context, 1000),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Custom ml Row + Undo Button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
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
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _logCustomWater(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _logCustomWater(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Add ➕',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

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
                        'Undo Last Log ↩️',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 5. Mini Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: '🔥 Streak',
                          value: '${provider.currentStreak} Days',
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: '🏆 Best',
                          value: '${provider.bestStreak} Days',
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80), // bottom space for FAB
                ],
              ),
            ),
          ),

          // 6. Floating Action Button for Hydration Coach AI (Emoji Only)
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openCoachSheet(context),
            backgroundColor: const Color(0xFF00E5FF),
            elevation: 8,
            child: const Text('🤖', style: TextStyle(fontSize: 24)),
          ),
        );
      },
    );
  }

  Widget _buildQuickLogBtn({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
}
