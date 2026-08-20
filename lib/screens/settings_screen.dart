import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../services/pref_service.dart';
import '../services/notification_service.dart';
// import '../widgets/diagnostic_logs_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _goalController;
  bool _isBatteryExempt = true; // assume OK until checked

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<HydrationProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.userName);
    _goalController = TextEditingController(text: (provider.dailyGoalMl / 1000).toStringAsFixed(1));
    _checkBatteryStatus();
  }

  Future<void> _checkBatteryStatus() async {
    final exempt = await NotificationService.isBatteryOptimizationExempt();
    if (mounted) {
      setState(() => _isBatteryExempt = exempt);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _saveName(HydrationProvider provider) async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await provider.updateUserName(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '👤 Name updated to $name',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF1565C0),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _saveGoal(HydrationProvider provider, double goalLiters) async {
    final goalMl = (goalLiters * 1000).round();
    setState(() {
      _goalController.text = goalLiters.toStringAsFixed(1);
    });
    await provider.updateGoal(goalMl);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎯 Daily Goal updated to ${goalLiters}L ($goalMl ml)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1565C0),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addReminderTime(BuildContext context, HydrationProvider provider) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final timeStr = DateFormat('hh:mm a').format(dt);
      await provider.addReminderTime(timeStr);

      final target = NotificationService.calculateNextTzOccurrence(timeStr);
      final banner = NotificationService.formatAlarmConfirmation(target);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(banner),
            backgroundColor: const Color(0xFF1565C0),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Settings ⚙️',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Configure user profile, hydration targets, notifications & privacy',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ⚡ Battery Optimization Warning Banner
                  if (!_isBatteryExempt) ...[
                    _BatteryGuidanceBanner(
                      onFixed: _checkBatteryStatus,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. 👤 User Profile Section
                  _buildCard(
                    title: '👤 User Profile',
                    subtitle: 'Update your display name',
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1565C0),
                          child: Text(
                            provider.userName.isNotEmpty ? provider.userName[0].toUpperCase() : 'U',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter name...',
                              hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _saveName(provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. 🎯 Daily Goal Target Section
                  _buildCard(
                    title: '🎯 Daily Goal Target',
                    subtitle: 'Set daily intake target in Liters',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _goalController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  suffixText: 'L',
                                  suffixStyle: GoogleFonts.poppins(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final val = double.tryParse(_goalController.text);
                                if (val != null && val > 0) {
                                  _saveGoal(provider, val);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Set Target', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Presets
                        Row(
                          children: [
                            _buildPresetChip(provider, 2.0),
                            _buildPresetChip(provider, 2.5),
                            _buildPresetChip(provider, 3.0),
                            _buildPresetChip(provider, 3.5),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. 🔔 Notifications & Scheduled Reminders Section
                  _buildCard(
                    title: '🔔 Offline Notifications & Reminders',
                    subtitle: 'Manage local hydration alarm times',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Enable Hydration Alerts', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
                          subtitle: Text('Receive offline reminders during the day', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
                          value: provider.isNotifEnabled,
                          activeColor: const Color(0xFF00E5FF),
                          onChanged: (val) => provider.toggleNotif(val),
                        ),
                        const Divider(color: Colors.white10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Post-Meal Reminder (30 mins)', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
                          subtitle: Text('Alert 30 minutes after scheduled meals', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
                          value: provider.isPostMealNotifEnabled,
                          activeColor: const Color(0xFF00E5FF),
                          onChanged: (val) => provider.togglePostMealNotif(val),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Scheduled Alarms & Reminders:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            IconButton(
                              icon: const Icon(Icons.add_alarm_rounded, color: Color(0xFF00E5FF)),
                              onPressed: () => _addReminderTime(context, provider),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Column(
                          children: provider.reminderTimes.map((timeStr) {
                            final displayTime = PrefService.formatTo12H(timeStr);
                            final isEnabled = provider.isReminderEnabled(timeStr);
                            final isDaily = provider.isReminderDaily(timeStr);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isEnabled ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : Colors.white10,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.alarm_rounded,
                                    size: 18,
                                    color: isEnabled ? const Color(0xFF00E5FF) : Colors.white38,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayTime,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isEnabled ? Colors.white : Colors.white38,
                                          ),
                                        ),
                                        // Daily / Once chip
                                        GestureDetector(
                                          onTap: isEnabled
                                              ? () async {
                                                  await provider.toggleReminderDaily(timeStr, !isDaily);
                                                  if (context.mounted) {
                                                    final label = !isDaily ? 'daily 🔁' : 'one-time only 1️⃣';
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('$displayTime set to repeat $label'),
                                                        duration: const Duration(seconds: 2),
                                                        backgroundColor: const Color(0xFF1565C0),
                                                      ),
                                                    );
                                                  }
                                                }
                                              : null,
                                          child: Container(
                                            margin: const EdgeInsets.only(top: 3),
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDaily
                                                  ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                                                  : Colors.orange.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isDaily
                                                    ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                                                    : Colors.orange.withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Text(
                                              isDaily ? '🔁 Daily' : '1️⃣ Once',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isDaily
                                                    ? const Color(0xFF00E5FF)
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // On / Off Toggle Switch
                                  Switch(
                                    value: isEnabled,
                                    activeColor: const Color(0xFF00E5FF),
                                    onChanged: (val) async {
                                      await provider.toggleReminderActive(timeStr, val);
                                      if (context.mounted) {
                                        if (val) {
                                          final target = NotificationService.calculateNextTzOccurrence(timeStr);
                                          final banner = NotificationService.formatAlarmConfirmation(target);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(banner),
                                              backgroundColor: const Color(0xFF1565C0),
                                              duration: const Duration(seconds: 4),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('🔕 Alarm for $displayTime turned off & cancelled.'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  // Delete Button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white60),
                                    onPressed: () async {
                                      await provider.removeReminderTime(timeStr);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('🗑️ Alarm for $displayTime deleted & cancelled.'),
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
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await NotificationService.showTestNotification();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('🔔 Instant notification sent to status bar!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.notifications_active_rounded, size: 16, color: Color(0xFF00E5FF)),
                                label: Text(
                                  'Instant Test',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00E5FF)),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  side: const BorderSide(color: Color(0xFF00E5FF)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            /*
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    final scheduledTime = await NotificationService.scheduleOneMinuteTest();
                                    final timeStr = DateFormat('hh:mm:ss a').format(scheduledTime);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('⏳ 1-Min Alarm set for $timeStr! Lock phone & wait 60s.'),
                                          backgroundColor: const Color(0xFF1565C0),
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('⚠️ Alarm scheduling error: $e'),
                                          backgroundColor: const Color(0xFFEF4444),
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.timer_outlined, size: 16, color: Colors.white),
                                label: Text(
                                  '1-Min Test Alarm',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  backgroundColor: const Color(0xFF1565C0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            */
                          ],
                        ),
                      ],
                    ),
                  ),

                  /*
                  const SizedBox(height: 16),

                  // 4. 🛡️ Diagnostics & Error Logs Section
                  _buildCard(
                    title: '🛡️ Diagnostics & Error Logs',
                    subtitle: 'Inspect system health, background alarms & error traces',
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => DiagnosticLogsSheet.show(context),
                        icon: const Icon(Icons.bug_report_outlined, size: 18, color: Color(0xFF00E5FF)),
                        label: Text(
                          'View Diagnostic Logs & Errors',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF00E5FF)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  */

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPresetChip(HydrationProvider provider, double liters) {
    final isSelected = (provider.dailyGoalMl / 1000).toStringAsFixed(1) == liters.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text('${liters}L', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white)),
        selected: isSelected,
        selectedColor: const Color(0xFF00E5FF),
        backgroundColor: const Color(0xFF0F172A),
        onSelected: (_) => _saveGoal(provider, liters),
      ),
    );
  }
}

// =============================================================================
// ⚡ Battery Guidance Banner — shown inside Settings when battery is not exempt
// =============================================================================

class _BatteryGuidanceBanner extends StatefulWidget {
  final VoidCallback onFixed;
  const _BatteryGuidanceBanner({required this.onFixed});

  @override
  State<_BatteryGuidanceBanner> createState() => _BatteryGuidanceBannerState();
}

class _BatteryGuidanceBannerState extends State<_BatteryGuidanceBanner> {
  bool _isExpanded = false;
  bool _showManualSteps = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Clickable with Dropdown Arrow)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.battery_alert_rounded, color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚡ Battery Optimization is ON',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        if (!_isExpanded)
                          Text(
                            'Tap to fix background alarm delivery on Samsung',
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.white60),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.orangeAccent, height: 1, thickness: 0.3),
                  const SizedBox(height: 10),
                  Text(
                    'Samsung One UI can kill background alarms even with all permissions granted. '
                    'Two settings need to be fixed for reliable delivery:',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),

          // Fix 1 — Standard Android exemption
          Text(
            'Fix 1 — Unrestricted Battery Mode',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await NotificationService.requestBatteryOptimizationExemption();
                await Future.delayed(const Duration(milliseconds: 800));
                widget.onFixed();
              },
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: Text(
                'Allow Unrestricted Battery',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Fix 2 — Samsung Device Care / App Sleep
          Text(
            'Fix 2 — Samsung App Sleep (Never Sleeping Apps)',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Samsung\'s "App Sleep" can suppress alarms separately from battery optimization.',
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await NotificationService.openSamsungDeviceCare();
              },
              icon: const Icon(Icons.phone_android_rounded, size: 16, color: Colors.orange),
              label: Text(
                'Open Samsung Device Care',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Collapsible manual guide
          GestureDetector(
            onTap: () => setState(() => _showManualSteps = !_showManualSteps),
            child: Row(
              children: [
                Icon(
                  _showManualSteps ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  _showManualSteps ? 'Hide manual steps' : 'Show manual steps (if buttons don\'t work)',
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ),

          if (_showManualSteps) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _manualStep('1', 'Open Samsung Settings'),
                  _manualStep('2', 'Tap Battery → Background usage limits'),
                  _manualStep('3', 'Tap Never sleeping apps → + (Add)'),
                  _manualStep('4', 'Find and select Hydro Tracker'),
                  const Divider(color: Colors.white12, height: 14),
                  _manualStep('A', 'Also go to: Settings → Apps → Hydro Tracker'),
                  _manualStep('B', 'Tap Battery → Select Unrestricted'),
                ],
              ),
            ),
          ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _manualStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              number,
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Battery Guidance Bottom Sheet — shown once on first launch
// =============================================================================

class BatteryGuidanceBottomSheet extends StatelessWidget {
  final VoidCallback? onDismiss;
  const BatteryGuidanceBottomSheet({super.key, this.onDismiss});

  static Future<void> showIfNeeded(BuildContext context) async {
    final alreadyShown = await PrefService.getBatteryPromptShown();
    if (alreadyShown) return;

    final isExempt = await NotificationService.isBatteryOptimizationExempt();
    if (isExempt) return; // Battery already OK — don't bother the user

    // Mark as shown before presenting, so it never shows twice even if dismissed instantly
    await PrefService.setBatteryPromptShown(true);

    // Guard against context becoming stale across the async gaps above
    if (!context.mounted) return;

    // ignore: use_build_context_synchronously — mounted guard is above
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BatteryGuidanceBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Action needed for reliable alarms',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              'Samsung One UI\'s battery optimization can silently suppress your '
              'hydration alarms, even when all permissions are granted.\n\n'
              'Two quick fixes take less than 30 seconds:',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70, height: 1.5),
            ),

            const SizedBox(height: 16),

            // Fix 1
            _sheetFixRow(
              icon: Icons.bolt_rounded,
              title: 'Fix 1 — Allow Unrestricted Battery',
              subtitle: 'Prevents Samsung from throttling the AlarmManager',
              color: Colors.orange,
              onTap: () async {
                await NotificationService.requestBatteryOptimizationExemption();
              },
            ),

            const SizedBox(height: 10),

            // Fix 2
            _sheetFixRow(
              icon: Icons.phone_android_rounded,
              title: 'Fix 2 — Never Sleeping Apps (Samsung)',
              subtitle: 'Device Care → Battery → Background usage limits',
              color: const Color(0xFF00E5FF),
              onTap: () async {
                await NotificationService.openSamsungDeviceCare();
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Done — I\'ve applied the fixes',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetFixRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54)),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
