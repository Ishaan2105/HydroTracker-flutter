import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/hydro_top_bar.dart';
import '../widgets/waves_background.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HydrationProvider>();
    final isDark = provider.isDarkMode;
    final colors = AppColors(isDark: isDark);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: const HydroTopBar(showBackButton: true),
      body: Stack(
        children: [
          // Ambient Water Wave Background with dynamic theme coloring
          WavesBackground(
            backgroundColor: colors.scaffoldBg,
            lineColor: isDark ? const Color(0x1F00E5FF) : const Color(0x150284C7),
          ),

          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Header Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF00E5FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/images/logo.jpeg',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 28),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hydro Tracker',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Version 2.0 • Community Edition',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Comprehensive Operating Guide & System Specifications',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 1
                  _buildSectionHeader('1. PRODUCT OVERVIEW & DESIGN PHILOSOPHY', colors),
                  _buildContentCard([
                    _buildSubHeading('1.1 Introduction', colors),
                    _buildParagraph(
                      'Hydro Tracker is a modern, privacy-first hydration tracking, habit-building, and community competition application built with Flutter and Dart. Designed with an offline-first architecture, your health logs and settings save instantly to local SQLite storage with zero UI latency, while seamlessly synchronizing with Google Cloud Firestore in the background when connected.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('1.2 Core Architectural Highlights', colors),
                    _buildBullet('Offline-First Speed (0ms Latency)', 'All logs and calculations write immediately to sandboxed device storage without depending on network availability.', colors),
                    _buildBullet('Automated Background Cloud Sync', 'Every drink entry, streak milestone, and goal adjustment automatically synchronizes with your secure Google Cloud profile in real time.', colors),
                    _buildBullet('Glass Intake Measurement Engine', 'Track water by natural glass counts (e.g. 5 glasses = 1000 mL) with customizable glass capacities.', colors),
                    _buildBullet('Global Community Leaderboard', 'Compete with verified hydrators worldwide on active streak days, with privacy controls allowing incognito mode.', colors),
                    _buildBullet('Precision Alarm Engine', 'Utilizes native Android OS AlarmManager with exact scheduling permissions to guarantee reminders trigger on time, even under aggressive OEM battery managers.', colors),
                    _buildBullet('Interactive Fluid UI & Dynamic Themes', 'Features real-time wave physics canvas with seamless Light Mode, OLED Dark Mode, and Auto-Schedule.', colors),
                  ], colors),
                  const SizedBox(height: 20),

                  // Section 2
                  _buildSectionHeader('2. INTAKE TRACKING & LOGGING WORKFLOWS', colors),
                  _buildContentCard([
                    _buildSubHeading('2.1 Quick Preset Buttons', colors),
                    _buildParagraph(
                      'Tap any instant preset button (+250ml, +500ml, +750ml, +1000ml) on the Home Screen for 1-tap logging with pleasant haptic feedback.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('2.2 Custom Glass Tracker & Editable Capacity', colors),
                    _buildParagraph(
                      'Many people count hydration by the number of glasses they drink throughout the day. Hydro Tracker lets you configure your personal glass volume and log multiple glasses at once:\n\n'
                      '• Configuring & Editing Glass Size: Tap the "Glass" button on the Home Screen (placed on the left for easy access). Tap the inline "Glass Size: Xml • Edit" pill to choose common presets (150ml, 200ml, 250ml, 300ml, 350ml, or 500ml) or type a custom volume (50–1000 mL). You can also edit your glass capacity anytime in Settings under "Glass Capacity (ml)".\n'
                      '• Multi-Glass Stepper: Use the [ - ] and [ + ] buttons to select how many glasses you drank (e.g. 5 glasses). The live preview calculates the total volume (5 × 200ml = 1000ml / 1.0L).\n'
                      '• One-Tap Logging: Tap the confirmation button to record the entire volume in a single action.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('2.3 Custom Milliliter Input', colors),
                    _buildParagraph(
                      'Enter any custom water amount into the "Custom ml..." field and tap the checkmark icon or press Done on your keyboard.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('2.4 Undo Last Log', colors),
                    _buildParagraph(
                      'Accidentally logged an incorrect amount? Tap "Undo Last Log" to revert your most recent drink entry immediately and recalculate your daily progress and streak.',
                      colors,
                    ),
                  ], colors),
                  const SizedBox(height: 20),

                  // Section 3
                  _buildSectionHeader('3. GLOBAL COMMUNITY STREAK LEADERBOARD', colors),
                  _buildContentCard([
                    _buildSubHeading('3.1 Live Standings & Olympic Podium', colors),
                    _buildParagraph(
                      'Participate in friendly community competition in the Leaderboard tab:\n\n'
                      '• #1 Gold Champion: Decorated with celebratory crown, shimmering gold border, and leading streak days.\n'
                      '• #2 Silver & #3 Bronze: Olympic podium showcasing the top three daily streak hydrators.\n'
                      '• Challengers (#4+): Ranked community list with avatars, current streak, and total volume logged.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('3.2 Ranking Criteria & Tie-Breakers', colors),
                    _buildParagraph(
                      '1. Primary Metric: Active consecutive streak days (descending order).\n'
                      '2. Tie-Breaker: Total lifetime water volume logged in mL. If two users share the same streak, the user who logged more lifetime hydration earns the higher rank.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('3.3 Privacy & Incognito Mode', colors),
                    _buildParagraph(
                      'In Settings under "Participate in Global Leaderboard", you can toggle public visibility off at any time. When toggled off, your account is immediately delisted from the public leaderboard while allowing you to view community standings in incognito mode.',
                      colors,
                    ),
                  ], colors),
                  const SizedBox(height: 20),

                  // Section 4
                  _buildSectionHeader('4. HOME & LOCK SCREEN WIDGETS', colors),
                  _buildContentCard([
                    _buildSubHeading('4.1 Adding the Sleek Widget', colors),
                    _buildParagraph(
                      'Hydro Tracker includes a frosted glassmorphic Android AppWidget with 0ms launch delay:\n\n'
                      '• 1-Tap Home Pinning: Go to Advanced Options in the app and tap "Add to Home Screen". A system confirmation dialog with a live preview will pin it to your desktop.\n'
                      '• Manual Placement: Long-press an empty space on your Android home screen → tap "Widgets" → locate Hydro Tracker → drag onto your desktop.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('4.2 Smart Quick-Log Buttons', colors),
                    _buildParagraph(
                      'The widget displays two primary capsule buttons:\n\n'
                      '1. Button 1: "Glass" Button: Records your configured glass capacity in the background with zero latency. If you haven\'t configured a glass size yet, tapping "Glass" automatically opens the Glass Setup Sheet inside the app so you can set your capacity.\n'
                      '2. Button 2: "+250 ml" Button: Instantly logs 250 mL directly to your daily intake and synchronizes across all devices.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('4.3 Dynamic Resizing & Adaptive Scaling', colors),
                    _buildParagraph(
                      'The Hydro Tracker widget supports fluid resizing on your home screen (e.g. 3×1, 3×2, 4×2, 4×3). When you stretch the widget vertically, its internal layout automatically scales: the progress ring expands with the official circular logo, the intake readout enlarges, and the quick-log buttons expand to comfortable 48dp touch targets.',
                      colors,
                    ),
                  ], colors),
                  const SizedBox(height: 20),

                  // Section 5
                  _buildSectionHeader('5. AUTOMATED GOOGLE CLOUD SYNC', colors),
                  _buildContentCard([
                    _buildSubHeading('5.1 Zero-Touch Real-Time Backup', colors),
                    _buildParagraph(
                      'When signed in with Google, you never need to manually press a sync button. Hydro Tracker automatically synchronizes every log, deletion, streak update, and daily goal adjustment to Google Cloud Firestore in real time.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('5.2 Multi-Device & Account Restoration', colors),
                    _buildParagraph(
                      'Upgraded phones or reinstalled the app? Simply sign in with your Google Account during onboarding to restore your streak, goals, and history instantly.',
                      colors,
                    ),
                  ], colors),
                  const SizedBox(height: 20),

                  // Section 6
                  _buildSectionHeader('6. THE 10-TIER HYDRATION RANK SYSTEM', colors),
                  _buildContentCard([
                    _buildParagraph(
                      'Hydro Tracker dynamically calculates your hydration progress throughout the day and assigns a rank from Level 1 to Level 10:',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildRankRow('Level 1', 'Desert Dweller', '0% – 9%', 'Dehydrated state; immediate intake recommended.', const Color(0xFFEF4444), colors),
                    _buildRankRow('Level 2', 'Mist Seeker', '10% – 19%', 'Low intake; drink a full glass promptly.', const Color(0xFFEAB308), colors),
                    _buildRankRow('Level 3', 'Dew Dropper', '20% – 29%', 'Minimal intake recorded; keep sipping.', const Color(0xFFF97316), colors),
                    _buildRankRow('Level 4', 'Puddle Jumper', '30% – 39%', 'Basic hydration logged; needs acceleration.', const Color(0xFFEC4899), colors),
                    _buildRankRow('Level 5', 'Stream Sailor', '40% – 49%', 'Making progress along the hydration stream.', const Color(0xFF8B5CF6), colors),
                    _buildRankRow('Level 6', 'River Guide', '50% – 59%', 'Halfway mark reached with regular pacing.', const Color(0xFF6366F1), colors),
                    _buildRankRow('Level 7', 'Current Commander', '60% – 69%', 'Steady fluid control throughout the day.', const Color(0xFF3B82F6), colors),
                    _buildRankRow('Level 8', 'Wave Rider', '70% – 79%', 'Smooth and consistent water drinking habit.', const Color(0xFF06B6D4), colors),
                    _buildRankRow('Level 9', 'Shield Guardian', '80% – 89%', 'Optimal hydration protecting health and focus.', const Color(0xFF10B981), colors),
                    _buildRankRow('Level 10', 'Ocean Master', '90% – 100%+', 'Peak hydration mastery; daily goal fulfilled.', const Color(0xFF00E5FF), colors),
                  ], colors),
                  const SizedBox(height: 20),

                  // Section 7
                  _buildSectionHeader('7. BATTERY OPTIMIZATION & TROUBLESHOOTING', colors),
                  _buildContentCard([
                    _buildSubHeading('7.1 Bypassing OEM Background Restrictions', colors),
                    _buildParagraph(
                      'To guarantee hourly and post-meal alarms fire exactly on schedule when your screen is locked:\n\n'
                      '• Samsung: Settings → Apps → Hydro Tracker → Battery → Unrestricted. In Background usage limits, add Hydro Tracker to "Never sleeping apps".\n'
                      '• Xiaomi (MIUI/HyperOS): App Info → Battery Saver → "No Restrictions" & enable Autostart.\n'
                      '• OnePlus / Oppo / Realme: App Info → Battery Usage → "Allow background activity".\n'
                      '• Google Pixel / Stock Android: Settings → Apps → Hydro Tracker → App battery usage → Unrestricted.',
                      colors,
                    ),
                    const SizedBox(height: 12),
                    _buildSubHeading('7.2 Hardware Alarm Verification', colors),
                    _buildParagraph(
                      '1. Open Settings → Tap "Test 1-Min Alarm".\n'
                      '2. Lock your phone screen and wait 60 seconds.\n'
                      '3. If the alarm sounds and vibrates while locked, your precision engine is fully exempted and running with 100% accuracy.',
                      colors,
                    ),
                  ], colors),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: colors.cyanAccent,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildContentCard(List<Widget> children, AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSubHeading(String title, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text, AppColors colors) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: colors.textSecondary,
        height: 1.5,
      ),
    );
  }

  Widget _buildBullet(String title, String desc, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: colors.cyanAccent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(fontSize: 12, color: colors.textSecondary, height: 1.4),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(String level, String title, String range, String desc, Color color, AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.cardBgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              level,
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    Text(
                      range,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.poppins(fontSize: 10.5, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
