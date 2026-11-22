import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../services/app_update_service.dart';
import '../services/pref_service.dart';
import '../services/notification_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_colors.dart';
import '../widgets/hydro_top_bar.dart';
import '../widgets/waves_background.dart';
import 'auth_gate_screen.dart';
// import '../widgets/diagnostic_logs_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final bool autoFocusUsername;
  const SettingsScreen({super.key, this.autoFocusUsername = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late FocusNode _nameFocusNode;
  late TextEditingController _goalController;
  late TextEditingController _glassController;
  final ScrollController _glassScrollController = ScrollController();
  bool _isBatteryExempt = true; // assume OK until checked
  bool _isThemeExpanded = true;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<HydrationProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.userName);
    _nameFocusNode = FocusNode();
    _goalController = TextEditingController(text: (provider.baseRegularGoalMl / 1000).toStringAsFixed(1));
    _glassController = TextEditingController(text: '${provider.customGlassMl}');
    _checkBatteryStatus();

    if (widget.autoFocusUsername) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nameFocusNode.requestFocus();
          _nameController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _nameController.text.length,
          );
        }
      });
    }
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
    _nameFocusNode.dispose();
    _goalController.dispose();
    _glassController.dispose();
    _glassScrollController.dispose();
    super.dispose();
  }

  void _saveName(HydrationProvider provider) async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      _nameFocusNode.unfocus();
      await provider.updateUserName(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Username updated to $name! Synced to Leaderboard.',
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
    await provider.updateBaseRegularGoal(goalMl);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Daily Goal updated to ${goalLiters}L ($goalMl ml)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1565C0),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveGlassSize(HydrationProvider provider, int sizeMl) async {
    final clamped = sizeMl.clamp(50, 1000);
    setState(() {
      _glassController.text = '$clamped';
    });
    await provider.setCustomGlassMl(clamped);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Glass capacity set to ${clamped}ml',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1565C0),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildGlassPresetChip(HydrationProvider provider, int sizeMl, AppColors colors) {
    final isSelected = provider.customGlassMl == sizeMl;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          '$sizeMl ml',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colors.primaryBlue : colors.textPrimary,
          ),
        ),
        selected: isSelected,
        selectedColor: colors.cyanAccent.withValues(alpha: 0.25),
        backgroundColor: colors.cardBgAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (selected) {
          if (selected) {
            _saveGlassSize(provider, sizeMl);
          }
        },
      ),
    );
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
        final colors = AppColors(isDark: provider.isDarkMode);

        return Scaffold(
          backgroundColor: colors.scaffoldBg,
          appBar: const HydroTopBar(showBackButton: true),
          body: WavesBackground(
            backgroundColor: colors.wavesBg,
            lineColor: colors.wavesLine,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Header
                  Text(
                    'Settings',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Configure user profile, hydration targets, notifications & privacy',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Battery Optimization Warning Banner
                  if (!_isBatteryExempt) ...[
                    _BatteryGuidanceBanner(
                      onFixed: _checkBatteryStatus,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 0. Google Cloud Sync & Account Section
                  _buildCloudSyncCard(context, provider, colors),
                  const SizedBox(height: 16),

                  // 1. User Profile Section
                  _buildCard(
                    title: 'User Profile',
                    subtitle: 'Update your display name',
                    colors: colors,
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
                            focusNode: _nameFocusNode,
                            style: GoogleFonts.poppins(color: colors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter name...',
                              hintStyle: GoogleFonts.poppins(color: colors.textMuted, fontSize: 13),
                              filled: true,
                              fillColor: colors.cardBgAlt,
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

                  // 2. Daily Goal Target Section
                  _buildCard(
                    title: 'Daily Goal Target',
                    subtitle: 'Set daily intake target in Liters',
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _goalController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.poppins(color: colors.textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  suffixText: 'L',
                                  suffixStyle: GoogleFonts.poppins(color: colors.cyanAccent, fontWeight: FontWeight.bold),
                                  filled: true,
                                  fillColor: colors.cardBgAlt,
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
                            _buildPresetChip(provider, 2.0, colors),
                            _buildPresetChip(provider, 2.5, colors),
                            _buildPresetChip(provider, 3.0, colors),
                            _buildPresetChip(provider, 3.5, colors),
                          ],
                        ),
                        if (provider.isWeatherBoostActive) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF97316), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Weather boost (+${provider.appliedWeatherBoostMl}ml) is active for today only. Resets to ${(provider.baseRegularGoalMl / 1000).toStringAsFixed(1)}L at 12:00 AM midnight.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFFEA580C),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2.5 Custom Glass Capacity Section
                  _buildCard(
                    title: 'Glass Capacity (ml)',
                    subtitle: 'Customize standard glass intake volume for 1-tap logging & widget',
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _glassController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                style: GoogleFonts.poppins(color: colors.textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  suffixText: 'ml',
                                  suffixStyle: GoogleFonts.poppins(color: colors.cyanAccent, fontWeight: FontWeight.bold),
                                  filled: true,
                                  fillColor: colors.cardBgAlt,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final val = int.tryParse(_glassController.text);
                                if (val != null && val >= 50 && val <= 1000) {
                                  _saveGlassSize(provider, val);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Set Size', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Presets with Sleek Horizontal Scrollbar
                        RawScrollbar(
                          controller: _glassScrollController,
                          thumbVisibility: true,
                          thickness: 3.5,
                          radius: const Radius.circular(2),
                          thumbColor: colors.cyanAccent.withValues(alpha: 0.6),
                          padding: const EdgeInsets.only(top: 6),
                          child: SingleChildScrollView(
                            controller: _glassScrollController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                _buildGlassPresetChip(provider, 150, colors),
                                _buildGlassPresetChip(provider, 200, colors),
                                _buildGlassPresetChip(provider, 250, colors),
                                _buildGlassPresetChip(provider, 300, colors),
                                _buildGlassPresetChip(provider, 350, colors),
                                _buildGlassPresetChip(provider, 500, colors),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Appearance & Theme Section (Dark Mode vs Light Mode)
                  _buildThemeCard(provider, colors),

                  const SizedBox(height: 16),

                  // 4. Notifications & Scheduled Reminders Section
                  _buildCard(
                    title: 'Offline Notifications & Reminders',
                    subtitle: 'Manage local hydration alarm times',
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Post-Meal Reminder (30 mins)', style: GoogleFonts.poppins(fontSize: 13, color: colors.textPrimary)),
                          subtitle: Text('Alert 30 minutes after scheduled meals', style: GoogleFonts.poppins(fontSize: 11, color: colors.textSecondary)),
                          value: provider.isPostMealNotifEnabled,
                          activeColor: colors.cyanAccent,
                          onChanged: (val) => provider.togglePostMealNotif(val),
                        ),
                        Divider(color: colors.surfaceBorder),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Participate in Global Leaderboard',
                            style: GoogleFonts.poppins(fontSize: 13, color: colors.textPrimary),
                          ),
                          subtitle: Text(
                            provider.isLeaderboardOptIn
                                ? 'Your streak & name are public on the community board'
                                : 'Private mode: You can view rankings without participating',
                            style: GoogleFonts.poppins(fontSize: 11, color: colors.textSecondary),
                          ),
                          value: provider.isLeaderboardOptIn,
                          activeColor: colors.cyanAccent,
                          onChanged: (val) async {
                            HapticFeedback.lightImpact();
                            final isSignedIn = CloudSyncService.instance.isSignedIn;
                            if (!isSignedIn && val) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please sign in with Google to participate in the global leaderboard.',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  action: SnackBarAction(
                                    label: 'Sign In',
                                    textColor: colors.cyanAccent,
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const AuthGateScreen()),
                                      );
                                    },
                                  ),
                                ),
                              );
                              return;
                            }
                            await provider.toggleLeaderboardOptIn(val);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: val ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                  content: Text(
                                    val
                                        ? 'Public Mode: Your streak is now live on the leaderboard!'
                                        : 'Private Mode: Your streak was removed from public rankings.',
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Scheduled Alarms & Reminders:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            IconButton(
                              icon: Icon(Icons.add_alarm_rounded, color: colors.cyanAccent),
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
                                color: colors.cardBgAlt,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isEnabled ? colors.cyanAccent.withValues(alpha: 0.4) : colors.surfaceBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.alarm_rounded,
                                    size: 18,
                                    color: isEnabled ? colors.cyanAccent : colors.textMuted,
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
                                            color: isEnabled ? colors.textPrimary : colors.textMuted,
                                          ),
                                        ),
                                        // Daily / Once chip
                                        GestureDetector(
                                          onTap: isEnabled
                                              ? () async {
                                                  await provider.toggleReminderDaily(timeStr, !isDaily);
                                                  if (context.mounted) {
                                                    final label = !isDaily ? 'daily' : 'one-time only';
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
                                                  ? colors.cyanAccent.withValues(alpha: 0.12)
                                                  : Colors.orange.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isDaily
                                                    ? colors.cyanAccent.withValues(alpha: 0.35)
                                                    : Colors.orange.withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Text(
                                              isDaily ? 'Daily' : 'Once',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isDaily
                                                    ? colors.cyanAccent
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
                                    activeColor: colors.cyanAccent,
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
                                              content: Text('Alarm for $displayTime turned off & cancelled.'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  // Delete Button
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.textSecondary),
                                    onPressed: () async {
                                      await provider.removeReminderTime(timeStr);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Alarm for $displayTime deleted & cancelled.'),
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
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final success = await NotificationService.showTestNotification();
                              if (context.mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Instant notification sent to status bar! 🔔'),
                                      backgroundColor: Color(0xFF10B981),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Notifications are disabled in Android. Please allow notifications.'),
                                      backgroundColor: const Color(0xFFEF4444),
                                      duration: const Duration(seconds: 4),
                                      action: SnackBarAction(
                                        label: 'Settings',
                                        textColor: Colors.white,
                                        onPressed: () => NotificationService.openNotificationSettings(),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.notifications_active_rounded, size: 16, color: colors.cyanAccent),
                            label: Text(
                              'Instant Test Notification',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: colors.cyanAccent),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              side: BorderSide(color: colors.cyanAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
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

                  Center(
                    child: Text(
                      'Hydro Tracker v${AppUpdateService.currentVersionName} (Build ${AppUpdateService.currentVersionCode})',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: colors.textSecondary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildCloudSyncCard(BuildContext context, HydrationProvider provider, AppColors colors) {
    final user = CloudSyncService.instance.currentUser;
    final isSignedIn = user != null;

    return _buildCard(
      title: 'Google Cloud Sync',
      subtitle: isSignedIn
          ? 'Real-time backup active across all devices'
          : 'Connect account to preserve streaks & logs',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSignedIn) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  backgroundImage: (user.photoURL != null && user.photoURL!.isNotEmpty)
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: (user.photoURL == null || user.photoURL!.isEmpty)
                      ? Text(
                          (user.displayName ?? user.email ?? 'U')[0].toUpperCase(),
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'HydroBuddy',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: colors.textPrimary, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email ?? '',
                        style: GoogleFonts.poppins(color: colors.textMuted, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text('Synced', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Real-time cloud sync active • All logs, streaks, and goals save automatically',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final provider = Provider.of<HydrationProvider>(context, listen: false);
                  await CloudSyncService.instance.signOut(provider);
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthGateScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 14),
                label: Text('Sign Out', style: GoogleFonts.poppins(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFF59E0B), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stored only on this device. Sign in to sync across devices.',
                    style: GoogleFonts.poppins(color: colors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthGateScreen()),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 16),
                label: Text('Link Google Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required Widget child,
    required AppColors colors,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: colors.textSecondary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPresetChip(HydrationProvider provider, double liters, AppColors colors) {
    final isSelected = (provider.baseRegularGoalMl / 1000).toStringAsFixed(1) == liters.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          '${liters}L',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? (colors.isDark ? Colors.black : Colors.white) : colors.textPrimary,
          ),
        ),
        selected: isSelected,
        selectedColor: colors.cyanAccent,
        backgroundColor: colors.cardBgAlt,
        onSelected: (_) => _saveGoal(provider, liters),
      ),
    );
  }

  Widget _buildThemeCard(HydrationProvider provider, AppColors colors) {
    final mode = provider.themeMode;
    final isAuto = mode == 'auto';
    final isLight = mode == 'light';
    final isDark = mode == 'dark';
    final isDay = HydrationProvider.isDaytime();

    String currentModeLabel;
    if (isAuto) {
      currentModeLabel = isDay
          ? 'Auto Schedule • Currently Light (Daytime)'
          : 'Auto Schedule • Currently Dark (Nighttime)';
    } else if (isLight) {
      currentModeLabel = 'Always Light Mode (Day & Night)';
    } else {
      currentModeLabel = 'Always Dark Mode (Day & Night)';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          InkWell(
            onTap: () => setState(() => _isThemeExpanded = !_isThemeExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Appearance & Theme',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (isAuto) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'DEFAULT',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        currentModeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isThemeExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
          if (_isThemeExpanded) ...[
            const SizedBox(height: 16),

            // Option 1: Auto Schedule Card (6:30 AM Light / 6:30 PM Dark)
            InkWell(
              onTap: () => provider.setThemeMode('auto'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isAuto
                      ? colors.cyanAccent.withValues(alpha: 0.12)
                      : colors.cardBgAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAuto ? colors.cyanAccent : colors.surfaceBorder,
                    width: isAuto ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isAuto
                            ? colors.cyanAccent.withValues(alpha: 0.18)
                            : colors.surfaceBorder.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: isAuto ? colors.cyanAccent : colors.textSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Auto Schedule',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isAuto ? colors.cyanAccent : colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'DEFAULT',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Light Mode: 6:30 AM – 6:30 PM\nDark Mode: 6:30 PM – 6:30 AM',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: colors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.surfaceBorderSubtle),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                  size: 13,
                                  color: isDay ? Colors.amber : colors.cyanAccent,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    isDay
                                        ? 'Active: Light (Daytime)'
                                        : 'Active: Dark (Nighttime)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isAuto ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      color: isAuto ? colors.cyanAccent : colors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Option 2 & 3: Fixed Themes Header & Chips
            Text(
              'OR CHOOSE A FIXED THEME',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildThemeOption(
                    title: 'Always Light',
                    subtitle: 'Clean daytime 24/7',
                    icon: Icons.light_mode_rounded,
                    isSelected: isLight,
                    colors: colors,
                    onTap: () => provider.setThemeMode('light'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeOption(
                    title: 'Always Dark',
                    subtitle: 'Sleek OLED 24/7',
                    icon: Icons.dark_mode_rounded,
                    isSelected: isDark,
                    colors: colors,
                    onTap: () => provider.setThemeMode('dark'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.cardBgAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.surfaceBorderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    size: 16,
                    color: colors.cyanAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAuto
                          ? 'Automatic schedule enabled. Day runs in Light Mode (6:30 AM – 6:30 PM), then switches to Dark Mode at night.'
                          : (isLight
                              ? 'Always Light Mode active: overrides schedule, remains bright 24/7.'
                              : 'Always Dark Mode active: overrides schedule, remains dark 24/7.'),
                      style: GoogleFonts.poppins(fontSize: 11, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.cyanAccent.withValues(alpha: 0.12)
              : colors.cardBgAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.cyanAccent : colors.surfaceBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? colors.cyanAccent : colors.textSecondary,
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 18, color: colors.cyanAccent)
                else
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.textMuted, width: 1.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? colors.cyanAccent : colors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
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
    final isDark = context.watch<HydrationProvider>().isDarkMode;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black87;
    final mutedTextColor = isDark ? Colors.white60 : Colors.black54;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withValues(alpha: 0.10) : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: isDark ? 0.5 : 0.6)),
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
                  Icon(Icons.battery_alert_rounded, color: isDark ? Colors.orange : const Color(0xFFC2410C), size: 22),
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
                            color: isDark ? Colors.orange : Colors.black,
                          ),
                        ),
                        if (!_isExpanded)
                          Text(
                            'Tap to fix background alarm delivery on Android',
                            style: GoogleFonts.poppins(fontSize: 10, color: mutedTextColor),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.orange : const Color(0xFFC2410C),
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
                  Divider(color: isDark ? Colors.orangeAccent : Colors.orange.withValues(alpha: 0.5), height: 1, thickness: 0.3),
                  const SizedBox(height: 10),
                  Text(
                    'Android battery optimization and aggressive OEM power-management can suppress background alarms even with all permissions granted. Two settings ensure reliable delivery:',
                    style: GoogleFonts.poppins(fontSize: 11, color: secondaryTextColor),
                  ),
                  const SizedBox(height: 12),

          // Fix 1 — Standard Android exemption
          Text(
            'Fix 1 — Unrestricted Battery Mode',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: primaryTextColor),
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

          // Fix 2 — OEM Background Limits & App Sleep
          Text(
            'Fix 2 — Background Usage Limits & App Sleep',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: primaryTextColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Samsung\'s "App Sleep" can suppress alarms separately from battery optimization.',
            style: GoogleFonts.poppins(fontSize: 10, color: mutedTextColor),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await NotificationService.openSamsungDeviceCare();
              },
              icon: Icon(Icons.phone_android_rounded, size: 16, color: isDark ? Colors.orange : const Color(0xFFC2410C)),
              label: Text(
                'Open Samsung Device Care',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.orange : const Color(0xFFC2410C),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: (isDark ? Colors.orange : const Color(0xFFC2410C)).withValues(alpha: 0.6)),
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
                  color: mutedTextColor,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  _showManualSteps ? 'Hide manual steps' : 'Show manual steps (if buttons don\'t work)',
                  style: GoogleFonts.poppins(fontSize: 10, color: mutedTextColor),
                ),
              ],
            ),
          ),

          if (_showManualSteps) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : Colors.orange.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _manualStep('1', 'Open Samsung Settings', secondaryTextColor),
                  _manualStep('2', 'Tap Battery → Background usage limits', secondaryTextColor),
                  _manualStep('3', 'Tap Never sleeping apps → + (Add)', secondaryTextColor),
                  _manualStep('4', 'Find and select Hydro Tracker', secondaryTextColor),
                  Divider(color: isDark ? Colors.white12 : Colors.black12, height: 14),
                  _manualStep('A', 'Also go to: Settings → Apps → Hydro Tracker', secondaryTextColor),
                  _manualStep('B', 'Tap Battery → Select Unrestricted', secondaryTextColor),
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

  Widget _manualStep(String number, String text, Color textColor) {
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
            child: Text(text, style: GoogleFonts.poppins(fontSize: 11, color: textColor)),
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
              'Android\'s battery optimization and aggressive OEM background power-management can silently suppress or delay scheduled hydration alarms when your screen is locked. To ensure alarms fire with 100% accuracy, please grant Unrestricted background activity.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70, height: 1.5),
            ),

            const SizedBox(height: 16),

            // Fix 1
            _sheetFixRow(
              icon: Icons.bolt_rounded,
              title: 'Fix 1 — Allow Unrestricted Battery',
              subtitle: 'Prevents the Android OS from throttling AlarmManager',
              color: Colors.orange,
              onTap: () async {
                await NotificationService.requestBatteryOptimizationExemption();
              },
            ),

            const SizedBox(height: 10),

            // Fix 2
            _sheetFixRow(
              icon: Icons.phone_android_rounded,
              title: 'Fix 2 — OEM Background Limits (Samsung & Others)',
              subtitle: 'Device Care → Battery → Background limits',
              color: const Color(0xFF00E5FF),
              onTap: () async {
                await NotificationService.openSamsungDeviceCare();
              },
            ),

            const SizedBox(height: 12),

            // Expandable OEM Troubleshooting Tip
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: Colors.white70,
                iconColor: const Color(0xFF00E5FF),
                title: Text(
                  'Manufacturer Guide (Samsung, Xiaomi, OnePlus, Pixel)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00E5FF),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• Samsung: Settings → Apps → Hydro Tracker → Battery → Unrestricted, and Device Care → Battery → Background usage limits → Never sleeping apps.\n'
                      '• Xiaomi / HyperOS: Settings → Apps → Manage apps → Hydro Tracker → Autostart ON, and Battery saver → No restrictions.\n'
                      '• OnePlus / Oppo / Realme: App info → Battery usage → Allow background activity & Allow auto-launch.\n'
                      '• Google Pixel / Stock Android: Settings → Apps → Hydro Tracker → App battery usage → Unrestricted.',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.white60, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

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
