import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../services/pref_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _goalController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<HydrationProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.userName);
    _goalController = TextEditingController(text: (provider.dailyGoalMl / 1000).toStringAsFixed(1));
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
    await provider.updateGoal(goalMl);
    _goalController.text = goalLiters.toStringAsFixed(1);

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
    }
  }

  void _confirmClearAllData(BuildContext context, HydrationProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          '⚠️ Clear All Logs & Reset Data?',
          style: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This action will permanently delete all logged water intake records from SQLite and reset your streak to 0. This cannot be undone!',
          style: GoogleFonts.poppins(color: const Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text('Clear Everything', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.clearAllData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🗑️ All logs cleared and app reset!',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
        return Scaffold(
          backgroundColor: const Color(0xFF0B1329),
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
                            Text('Scheduled Reminder Times:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            IconButton(
                              icon: const Icon(Icons.add_alarm_rounded, color: Color(0xFF00E5FF)),
                              onPressed: () => _addReminderTime(context, provider),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: provider.reminderTimes.map((timeStr) {
                            final displayTime = PrefService.formatTo12H(timeStr);
                            return Chip(
                              backgroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFF00E5FF), width: 0.5),
                              label: Text(
                                displayTime,
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                              onDeleted: () => provider.removeReminderTime(timeStr),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. 🏆 Community Leaderboards Opt-In Settings
                  _buildCard(
                    title: '🏆 Leaderboards Privacy Settings',
                    subtitle: 'Control leaderboard participation visibility',
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Participate in Solo Leaderboard', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
                          subtitle: Text('Show streak & completion rate on solo board', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
                          value: provider.isSoloOptIn,
                          activeColor: const Color(0xFF00E5FF),
                          onChanged: (val) => provider.toggleSoloOptIn(val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6. ⚠️ Danger Zone Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C2D12).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('⚠️ Danger Zone', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
                        Text('Permanently wipe offline SQLite data and reset app streaks.', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFFFEDD5))),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
                            label: Text('Clear All Logs & Reset App', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
                            onPressed: () => _confirmClearAllData(context, provider),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
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
