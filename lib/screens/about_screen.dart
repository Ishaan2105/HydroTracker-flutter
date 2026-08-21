import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/hydro_top_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const HydroTopBar(showBackButton: true),
      body: SingleChildScrollView(
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
                            'Version 1.0.0 • Offline Edition',
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
                    'Comprehensive Operating Guide & Architecture Specification',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1
            _buildSectionHeader('1. PRODUCT OVERVIEW & DESIGN PHILOSOPHY'),
            _buildContentCard([
              _buildSubHeading('1.1 Introduction'),
              _buildParagraph(
                'Hydro Tracker is an intelligent, privacy-first, offline hydration tracking and habit-building mobile application built with Flutter and Dart. Designed to operate completely autonomously without requiring an internet connection, remote servers, or third-party cloud logins, Hydro Tracker stores all data locally in an encrypted SQLite database and schedules precision alerts directly through the Android OS Alarm Manager.',
              ),
              const SizedBox(height: 12),
              _buildSubHeading('1.2 Core Architectural Highlights'),
              _buildBullet('100% Offline-First Architecture', 'Your health data, logs, profile settings, and reminder schedules never leave your device.'),
              _buildBullet('Triple-Redundancy Alarm Engine', 'Combines native Android OS AlarmManager (with exact scheduling permissions), background intent receivers, and foreground active process timers to guarantee reminders trigger on time, even under aggressive battery management systems like Samsung One UI.'),
              _buildBullet('Interactive Fluid UI with Waves', 'Powered by a custom rendering canvas inspired by modern web visual standards, featuring real-time responsive wave animations.'),
              _buildBullet('Gamified Rank Progression', 'A 10-tier hydration hierarchy that updates dynamically based on daily target completion percentages.'),
              _buildBullet('Unified Top & Bottom Navigation', 'Consistent top app bar featuring your greeting, rank, settings gear, and streak counter across all primary screens.'),
            ]),
            const SizedBox(height: 20),

            // Section 2
            _buildSectionHeader('2. GETTING STARTED & SYSTEM REQUIREMENTS'),
            _buildContentCard([
              _buildSubHeading('2.1 Compatibility & Permissions'),
              _buildParagraph(
                'Hydro Tracker supports Android 8.0 (Oreo / API Level 26) through Android 14 (API Level 34) and above.\n\nTo ensure reliable background alarms and accurate tracking, the application utilizes the following core permissions:',
              ),
              const SizedBox(height: 8),
              _buildBullet('Post Notifications (POST_NOTIFICATIONS)', 'Required on Android 13+ to display reminders and goal banners.'),
              _buildBullet('Schedule Exact Alarms (SCHEDULE_EXACT_ALARM)', 'Required on Android 12+ to wake the device at precise reminder timestamps.'),
              _buildBullet('Battery Optimization Exemption', 'Crucial for continuous background scheduling when the screen is locked.'),
              const SizedBox(height: 12),
              _buildSubHeading('2.2 Initial Setup & First Launch'),
              _buildParagraph(
                '1. Set Your Profile: Open the Settings menu to enter your name and default daily target (default is 2500 ml).\n'
                '2. Exempt from Battery Saver: If prompted by the Battery Optimization banner on Samsung or other OEM devices, tap Enable Background Alarms and select Allow / Unrestricted.\n'
                '3. Configure Notifications: Ensure notifications are enabled to receive hourly and post-meal hydration prompts.',
              ),
            ]),
            const SizedBox(height: 20),

            // Section 3
            _buildSectionHeader('3. SCREEN-BY-SCREEN APPLICATION WALKTHROUGH'),
            _buildContentCard([
              _buildSubHeading('3.1 Home Screen (HomeScreen)'),
              _buildParagraph('The Home Screen is your primary dashboard for daily tracking, instant logging, weekly analytics, and trend monitoring:'),
              _buildBullet('Top Bar', 'Clean minimalist top bar featuring your greeting, settings gear button, and real-time streak badge.'),
              _buildBullet('Streak Risk Warning', 'Automated 4:00 PM pace alerts if daily intake is below 40% to protect your active streak.'),
              _buildBullet('Circular Progress Dial', 'Visualizes percentage completion, logged volume, and remaining goal with animated water waves.'),
              _buildBullet('Quick Log Row', 'Single horizontal row with instant presets for 250 ml, 500 ml, 750 ml, and 1000 ml.'),
              _buildBullet('Custom Volume Input & Add Button', 'Type exact milliliter amounts with a dedicated Add button and undo capability.'),
              _buildBullet('Streak Badges', 'Current Streak and All-Time Best Streak counters.'),
              _buildBullet('7-Day Hydration Trend', 'Proper bar graph comparing daily intake against the 100% target baseline with daily average and total volume badges.'),
              _buildBullet('Weekly Analytics', 'Automated weekly trend assessment with actionable hydration advice.'),
              _buildBullet('Highlights Row', 'Quick-glance metrics highlighting Best Day, Lowest Day, and 7-day Goal Hit Rate.'),
              const Divider(color: Colors.white12, height: 24),

              _buildSubHeading('3.2 Trends & Insights Screen (TrendsInsightsScreen)'),
              _buildParagraph('A dedicated history, planning, and habit progression hub:'),
              _buildBullet('1. Personalized Goal Calculator', 'Interactive biometric tool calculating target intake based on height (ft/in or cm), weight (kg), age, and gender.'),
              _buildBullet('2. Goal Status & Perfect Days', 'Side-by-side overview cards displaying completion status and total perfect days achieved.'),
              _buildBullet('3. Rank Roadmap & Tier Progress', 'Progress bar toward unlocking your next rank. Tap anywhere to view all 10 ranks ordered from Level 1 to Level 10.'),
              _buildBullet('4. 30-Day Activity Heatmap', 'Aesthetic minimalist heatmap with shrunk tiles, integrated 30-Day Success Rate, and date marker on today’s tile.'),
              _buildBullet('5. Timeline Log', 'Selected date breakdown showing timestamped sips. Deletion is protected and permitted exclusively for today’s logs.'),
              _buildBullet('6. Meal Times Schedule', 'Breakfast, Lunch, and Dinner schedule for 30-minute post-meal digestive reminders.'),
              const Divider(color: Colors.white12, height: 24),

              _buildSubHeading('3.3 Settings Modal & Configuration'),
              _buildParagraph('Accessed via the top-left gear icon:'),
              _buildBullet('Profile & Goals', 'Adjust your username and daily milliliter target.'),
              _buildBullet('Alarm Manager', 'Add, toggle, set Daily/Once repetition, or delete reminder times.'),
              _buildBullet('Diagnostics & Testing', '1-minute test alarm and instant notification tests.'),
              _buildBullet('Diagnostic Logger', 'Live in-app terminal showing background events and database activity.'),
              _buildBullet('Factory Data Reset', 'Completely wipe local SQLite tables and preferences.'),
            ]),
            const SizedBox(height: 20),

            // Section 4
            _buildSectionHeader('4. THE 10-TIER HYDRATION RANK SYSTEM'),
            _buildContentCard([
              _buildParagraph('Hydro Tracker evaluates your intake percentage daily and dynamically assigns a rank from Level 1 to Level 10:'),
              const SizedBox(height: 12),
              _buildRankRow('Level 1', 'Desert Dweller', '0% – 9%', 'Dehydrated state; immediate intake recommended.', const Color(0xFFEF4444)),
              _buildRankRow('Level 2', 'Mist Seeker', '10% – 19%', 'Low intake; drink a full glass promptly.', const Color(0xFFEAB308)),
              _buildRankRow('Level 3', 'Dew Dropper', '20% – 29%', 'Minimal intake recorded; keep sipping.', const Color(0xFFF97316)),
              _buildRankRow('Level 4', 'Puddle Jumper', '30% – 39%', 'Basic hydration logged; needs acceleration.', const Color(0xFFEC4899)),
              _buildRankRow('Level 5', 'Stream Sailor', '40% – 49%', 'Making progress along the hydration stream.', const Color(0xFF8B5CF6)),
              _buildRankRow('Level 6', 'River Guide', '50% – 59%', 'Halfway mark reached with regular pacing.', const Color(0xFF6366F1)),
              _buildRankRow('Level 7', 'Current Commander', '60% – 69%', 'Steady fluid control throughout the day.', const Color(0xFF3B82F6)),
              _buildRankRow('Level 8', 'Wave Rider', '70% – 79%', 'Smooth and consistent water drinking habit.', const Color(0xFF06B6D4)),
              _buildRankRow('Level 9', 'Shield Guardian', '80% – 89%', 'Optimal hydration protecting health and focus.', const Color(0xFF10B981)),
              _buildRankRow('Level 10', 'Ocean Master', '90% – 100%+', 'Peak hydration mastery; daily goal fulfilled.', const Color(0xFF00E5FF)),
            ]),
            const SizedBox(height: 20),

            // Section 5
            _buildSectionHeader('5. BATTERY OPTIMIZATION & TROUBLESHOOTING'),
            _buildContentCard([
              _buildSubHeading('5.1 Bypassing OEM Background Restrictions'),
              _buildParagraph(
                'Android OEMs employ aggressive background task management. To guarantee alarms fire on time:\n\n'
                '• Samsung One UI: Settings → Apps → Hydro Tracker → Battery → Unrestricted. Background usage limits → Add to Never sleeping apps.\n'
                '• Xiaomi (MIUI/HyperOS): App Info → Battery Saver → No Restrictions & enable Autostart.\n'
                '• OnePlus (OxygenOS): App Info → Battery Usage → Allow background activity.',
              ),
              const SizedBox(height: 12),
              _buildSubHeading('5.2 Hardware Alarm Verification'),
              _buildParagraph(
                '1. Open Settings → Tap Test 1-Min Alarm.\n'
                '2. Lock your phone screen and wait 60 seconds.\n'
                '3. If the alarm rings with sound and vibration while locked, your device engine is fully optimized.',
              ),
            ]),
            const SizedBox(height: 20),

            // Section 6
            _buildSectionHeader('6. DATA PRIVACY & BACKUP SPECIFICATION'),
            _buildContentCard([
              _buildBullet('Storage Location', 'Local SQLite database file (hydro_tracker.db) stored strictly inside sandboxed app storage.'),
              _buildBullet('Network Security', 'Zero network activity. No data is ever transmitted externally.'),
              _buildBullet('Resetting Data', 'Use Clear All Data in Settings to restore factory state.'),
            ]),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF00E5FF),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildContentCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSubHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: const Color(0xFFCBD5E1),
        height: 1.5,
      ),
    );
  }

  Widget _buildBullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF00E5FF),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFCBD5E1), height: 1.4),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildRankRow(String level, String title, String range, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
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
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
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
                  style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
