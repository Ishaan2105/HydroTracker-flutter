import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_logger.dart';
import '../services/notification_service.dart';
import '../services/db_helper.dart';

class DiagnosticLogsSheet extends StatefulWidget {
  const DiagnosticLogsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DiagnosticLogsSheet(),
    );
  }

  @override
  State<DiagnosticLogsSheet> createState() => _DiagnosticLogsSheetState();
}

class _DiagnosticLogsSheetState extends State<DiagnosticLogsSheet> {
  List<LogEntry> _logs = [];
  bool _loading = true;
  LogLevel? _selectedFilter;
  bool _batteryExempt = false;
  int _dbLogCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final logs = await AppLogger.getHistoricalLogs();
    final exempt = await NotificationService.isBatteryOptimizationExempt();
    final allWater = await DBHelper.instance.getAllLogs();

    if (mounted) {
      setState(() {
        _logs = logs;
        _batteryExempt = exempt;
        _dbLogCount = allWater.length;
        _loading = false;
      });
    }
  }

  Future<void> _copyLogs() async {
    final exportStr = await AppLogger.exportLogsString();
    await Clipboard.setData(ClipboardData(text: exportStr));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📋 All diagnostic logs copied to clipboard!',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1565C0),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearLogs() async {
    await AppLogger.clearAllLogs();
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🗑️ Diagnostic logs cleared.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF334155),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _selectedFilter == null
        ? _logs
        : _logs.where((l) => l.level == _selectedFilter).toList();

    final errorCount = _logs.where((l) => l.level == LogLevel.error || l.level == LogLevel.crash).length;
    final warnCount = _logs.where((l) => l.level == LogLevel.warn).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Header Row
              Row(
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnostic Logs & Errors',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Recorded runtime events, alarms & crash telemetry',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    tooltip: 'Refresh',
                    onPressed: _loadData,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Health Status Overview Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Battery Mode',
                      value: _batteryExempt ? 'Unrestricted' : 'Optimized',
                      color: _batteryExempt ? const Color(0xFF00E5FF) : Colors.orange,
                      icon: Icons.battery_charging_full_rounded,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Errors / Crashes',
                      value: errorCount.toString(),
                      color: errorCount > 0 ? Colors.redAccent : const Color(0xFF4ADE80),
                      icon: Icons.error_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Water Logs',
                      value: _dbLogCount.toString(),
                      color: const Color(0xFF38BDF8),
                      icon: Icons.water_drop_rounded,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'App Logs',
                      value: _logs.length.toString(),
                      color: const Color(0xFF818CF8),
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All (${_logs.length})', null),
                    const SizedBox(width: 6),
                    _buildFilterChip('💥 Crashes (${_logs.where((l) => l.level == LogLevel.crash).length})', LogLevel.crash),
                    const SizedBox(width: 6),
                    _buildFilterChip('🔴 Errors ($errorCount)', LogLevel.error),
                    const SizedBox(width: 6),
                    _buildFilterChip('🟡 Warnings ($warnCount)', LogLevel.warn),
                    const SizedBox(width: 6),
                    _buildFilterChip('🟢 Info (${_logs.where((l) => l.level == LogLevel.info).length})', LogLevel.info),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Log Entries List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredLogs.isEmpty
                        ? Center(
                            child: Text(
                              'No logs recorded for selected filter.',
                              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filteredLogs.length,
                            itemBuilder: (context, index) {
                              return _buildLogItem(filteredLogs[index]);
                            },
                          ),
              ),

              const SizedBox(height: 10),

              // Bottom Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _logs.isEmpty ? null : _copyLogs,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(
                        'Copy All Logs',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _logs.isEmpty ? null : _clearLogs,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.redAccent),
                    label: Text(
                      'Clear',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LogLevel? level) {
    final isSelected = _selectedFilter == level;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.black : Colors.white70,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF00E5FF),
      backgroundColor: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) => setState(() => _selectedFilter = level),
    );
  }

  Widget _buildLogItem(LogEntry log) {
    Color levelColor;
    switch (log.level) {
      case LogLevel.crash:
        levelColor = Colors.purpleAccent;
        break;
      case LogLevel.error:
        levelColor = Colors.redAccent;
        break;
      case LogLevel.warn:
        levelColor = Colors.orangeAccent;
        break;
      case LogLevel.info:
        levelColor = const Color(0xFF00E5FF);
        break;
    }

    final timeStr = "${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: log.level == LogLevel.error || log.level == LogLevel.crash
              ? levelColor.withValues(alpha: 0.4)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.level.name.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: levelColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.tag,
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.white70),
                ),
              ),
              const Spacer(),
              Text(
                timeStr,
                style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            log.message,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
          ),
          if (log.stackTrace != null && log.stackTrace!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                log.stackTrace!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.redAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
