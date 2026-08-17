import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class HydrationCoachSheet extends StatefulWidget {
  const HydrationCoachSheet({super.key});

  @override
  State<HydrationCoachSheet> createState() => _HydrationCoachSheetState();
}

class _HydrationCoachSheetState extends State<HydrationCoachSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _showQuickOptions = true;

  @override
  void initState() {
    super.initState();
    // Welcome message from Coach
    _messages.add(
      ChatMessage(
        text: "Hello! I am your Offline Hydration Coach 🤖. Ask me anything about your intake, streak, or schedule!",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final userMsg = text.trim();
    _controller.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: userMsg,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _showQuickOptions = false;
    });

    final provider = Provider.of<HydrationProvider>(context, listen: false);
    final botResponse = provider.getCoachResponse(userMsg);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: botResponse,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🤖', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hydration Coach',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Offline Data Intelligence',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
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
          ),
          const Divider(color: Colors.white10, height: 1),

          // Message List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: msg.isUser ? Radius.zero : const Radius.circular(16),
                        bottomLeft: msg.isUser ? const Radius.circular(16) : Radius.zero,
                      ),
                      border: Border.all(
                        color: msg.isUser ? Colors.transparent : Colors.white12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            DateFormat('hh:mm a').format(msg.timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick Options Chips
          if (_showQuickOptions) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildQuickChip('📊 How am I doing today?'),
                    _buildQuickChip('⏰ When should I drink next?'),
                    _buildQuickChip('🎯 What is my remaining goal?'),
                    _buildQuickChip('🔥 How is my streak?'),
                    _buildQuickChip('💡 Give me a hydration tip'),
                  ],
                ),
              ),
            ),
          ],

          // Input Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF020617),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ask offline coach...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.mic, color: Color(0xFF00E5FF)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎤 Offline voice input module ready!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1565C0),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF1E293B),
        side: const BorderSide(color: Color(0xFF00E5FF), width: 0.5),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFE2E8F0)),
        ),
        onPressed: () => _sendMessage(label),
      ),
    );
  }
}
