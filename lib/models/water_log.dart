class WaterLog {
  final int? id;
  final int amountMl;
  final DateTime timestamp;
  final String dateString;

  WaterLog({
    this.id,
    required this.amountMl,
    required this.timestamp,
    required this.dateString,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount_ml': amountMl,
      'timestamp': timestamp.toIso8601String(),
      'date_string': dateString,
    };
  }

  factory WaterLog.fromMap(Map<String, dynamic> map) {
    return WaterLog(
      id: (map['id'] as num?)?.toInt(),
      amountMl: (map['amount_ml'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.parse(map['timestamp'] as String),
      dateString: map['date_string'] as String,
    );
  }
}
