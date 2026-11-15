import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/waves_background.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String title;
  final String message;
  final String playStoreUrl;

  const ForceUpdateScreen({
    super.key,
    this.title = 'Update Required',
    this.message =
        'A mandatory update of Hydro Tracker is available on Google Play. Please update to continue tracking your hydration, competing on the leaderboard, and using the smart home widget.',
    this.playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.threestack.hydrotracker',
  });

  Future<void> _launchStore() async {
    final marketUri = Uri.parse('market://details?id=com.threestack.hydrotracker');
    final webUri = Uri.parse(playStoreUrl);

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents closing or bypassing via Android back button
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1329),
        body: Stack(
          children: [
            const WavesBackground(
              backgroundColor: Color(0xFF0B1329),
              lineColor: Color(0x2000E5FF),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Glowing Logo Badge
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.system_update_rounded,
                              size: 64,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Update Pill Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.rocket_launch_rounded, size: 14, color: Color(0xFF00E5FF)),
                            const SizedBox(width: 6),
                            Text(
                              'NEW VERSION AVAILABLE',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00E5FF),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: const Color(0xFF94A3B8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Key Features Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131D38),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x3300E5FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "What's in the update:",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildFeatureItem(
                              icon: Icons.leaderboard_rounded,
                              title: 'Community Leaderboard',
                              desc: 'Live streak ranks & champion podiums',
                            ),
                            const SizedBox(height: 8),
                            _buildFeatureItem(
                              icon: Icons.widgets_rounded,
                              title: 'Adaptive Android Widget',
                              desc: 'Custom glass quick-logging & fluid resizing',
                            ),
                            const SizedBox(height: 8),
                            _buildFeatureItem(
                              icon: Icons.cloud_sync_rounded,
                              title: 'Zero-Loss Cloud Sync',
                              desc: 'Instant Google sign-in & streak backup',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Update on Google Play Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _launchStore,
                          icon: const Icon(Icons.shop_rounded, size: 22, color: Colors.black),
                          label: Text(
                            'Update on Google Play Store',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Hydro Tracker requires this update to connect to online services.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF00E5FF)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
