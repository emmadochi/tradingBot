class TradeSignal {
  final String id;
  final String symbol;
  final String pattern;
  final String direction;
  final double entry;
  final double sl;
  final double tp;
  final double rr;
  final String timestamp;
  final String status; // 'OPEN', 'WIN', 'LOSS', 'EXPIRED'
  final double resultR;
  final double? exitPrice;
  final String? exitTime;

  TradeSignal({
    required this.id,
    required this.symbol,
    required this.pattern,
    required this.direction,
    required this.entry,
    required this.sl,
    required this.tp,
    required this.rr,
    required this.timestamp,
    required this.status,
    required this.resultR,
    this.exitPrice,
    this.exitTime,
  });

  factory TradeSignal.fromJson(Map<String, dynamic> json) {
    return TradeSignal(
      id: json['id']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? 'R_25',
      pattern: json['pattern']?.toString() ?? 'Unknown',
      direction: json['direction']?.toString() ?? 'BUY',
      entry: (json['entry'] as num?)?.toDouble() ?? 0.0,
      sl: (json['sl'] as num?)?.toDouble() ?? 0.0,
      tp: (json['tp'] as num?)?.toDouble() ?? 0.0,
      rr: (json['rr'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      resultR: (json['result_r'] as num?)?.toDouble() ?? 0.0,
      exitPrice: (json['exit_price'] as num?)?.toDouble(),
      exitTime: json['exit_time']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'pattern': pattern,
      'direction': direction,
      'entry': entry,
      'sl': sl,
      'tp': tp,
      'rr': rr,
      'timestamp': timestamp,
      'status': status,
      'result_r': resultR,
      'exit_price': exitPrice,
      'exit_time': exitTime,
    };
  }

  bool get isOpen => status == 'OPEN';
  bool get isWin => status == 'WIN';
  bool get isLoss => status == 'LOSS';
}
