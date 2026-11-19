import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../services/pref_service.dart';
import '../screens/settings_screen.dart';

class UsernameSetupDialog extends StatelessWidget {
  const UsernameSetupDialog({super.key});

  /// Presents the setup prompt only once to new users on first launch
  static Future<void> showIfNeeded(BuildContext context) async {
    final alreadyPrompted = await PrefService.hasPromptedUsernameSetup();
    if (alreadyPrompted) return;

    // Mark as prompted immediately so it never shows twice
    await PrefService.setHasPromptedUsernameSetup(true);

    if (!context.mounted) return;

    final provider = Provider.of<HydrationProvider>(context, listen: false);
    // If user already has a custom name set, no need to prompt
    if (provider.userName.trim().isNotEmpty && provider.userName.trim() != 'HydroBuddy') {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UsernameSetupDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HydrationProvider>();
    final isDark = provider.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Icon Badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.badge_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),

            const SizedBox(height: 18),

            // Title
            Text(
              'Welcome to Hydro Tracker! 💧',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 10),

            // Message
            Text(
              'Personalize your journey! Rename your username on the settings page so friends and hydrators worldwide can recognize you on the leaderboard.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 14),

            // Note Card explaining default fallback
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF0284C7),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If you keep "HydroBuddy", your email name will be shown on the leaderboard instead.',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Action 1: Go to Settings (Primary)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(autoFocusUsername: true),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                label: Text(
                  'Set Username in Settings',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Action 2: Keep Default (Secondary)
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Keep as "HydroBuddy"',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
