import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HydrationRanksSheet extends StatelessWidget {
  final String currentRank;

  const HydrationRanksSheet({
    super.key,
    required this.currentRank,
  });

  @override
  Widget build(BuildContext context) {
    final ranks = [
      {
        'title': 'Desert Dweller',
        'level': 'Level 1',
        'range': '0% – 9%',
        'desc': 'Dry climate! Low fluid levels, drink water now!',
        'color': const Color(0xFFEF4444),
      },
      {
        'title': 'Mist Seeker',
        'level': 'Level 2',
        'range': '10% – 19%',
        'desc': 'Emerging from the mist. Drink a full glass!',
        'color': const Color(0xFFEAB308),
      },
      {
        'title': 'Dew Dropper',
        'level': 'Level 3',
        'range': '20% – 29%',
        'desc': 'Fresh dew drops collected. Keep sipping!',
        'color': const Color(0xFFF97316),
      },
      {
        'title': 'Puddle Jumper',
        'level': 'Level 4',
        'range': '30% – 39%',
        'desc': 'Jumping over puddles, making steady progress.',
        'color': const Color(0xFFEC4899),
      },
      {
        'title': 'Stream Sailor',
        'level': 'Level 5',
        'range': '40% – 49%',
        'desc': 'Sailing steadily along the water stream.',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'River Guide',
        'level': 'Level 6',
        'range': '50% – 59%',
        'desc': 'Halfway there! Guiding your daily intake.',
        'color': const Color(0xFF6366F1),
      },
      {
        'title': 'Current Commander',
        'level': 'Level 7',
        'range': '60% – 69%',
        'desc': 'Commanding the fluid flow effectively.',
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Wave Rider',
        'level': 'Level 8',
        'range': '70% – 79%',
        'desc': 'Riding the wave smoothly to your target.',
        'color': const Color(0xFF06B6D4),
      },
      {
        'title': 'Shield Guardian',
        'level': 'Level 9',
        'range': '80% – 89%',
        'desc': 'Guarding your health with high hydration.',
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Ocean Master',
        'level': 'Level 10',
        'range': '90% – 100%+',
        'desc': 'Peak hydration mastery! Goal accomplished!',
        'color': const Color(0xFF00E5FF),
      },
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.military_tech_rounded, size: 28, color: Color(0xFF00E5FF)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All 10 Hydration Ranks',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Based on daily target completion %',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current Rank Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF00E5FF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 24, color: Colors.white),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR CURRENT RANK',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      currentRank,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ranks List
          Expanded(
            child: ListView.builder(
              itemCount: ranks.length,
              itemBuilder: (context, index) {
                final rank = ranks[index];
                final title = rank['title'] as String;
                final range = rank['range'] as String;
                final desc = rank['desc'] as String;
                final color = rank['color'] as Color;
                final isCurrent = currentRank.contains(title.replaceAll(RegExp(r'^[^\s]+\s+'), ''));

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? color : Colors.white10,
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    range,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
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
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '✓ ACTIVE',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
