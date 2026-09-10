import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trade_signal.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pulse_badge.dart';
import '../widgets/signal_card.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  List<TradeSignal> _liveSignals = [];
  bool _isLoading = true;
  bool _isOnline = true;
  bool _showBenchmarkPreview = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 15 seconds
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    final online = await ApiService.checkHealth();
    final live = await ApiService.fetchLiveSignals();

    if (mounted) {
      NotificationService.checkForNewSignals(context, live);
      setState(() {
        _isOnline = online;
        _liveSignals = live;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSignals = _liveSignals.where((s) => s.isOpen).toList();
    final recentClosed = _liveSignals.where((s) => !s.isOpen).take(6).toList();
    final benchmarkList = ApiService.getBacktestBenchmarkSignals();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final testSig = TradeSignal(
            id: 'test_${DateTime.now().millisecondsSinceEpoch}',
            symbol: 'R_25',
            pattern: 'Hammer',
            direction: 'BUY',
            entry: 2745.50,
            sl: 2738.20,
            tp: 2760.10,
            rr: 2.0,
            timestamp: 'Just Now',
            status: 'OPEN',
            resultR: 0.0,
            isLive: true,
          );
          NotificationService.triggerAlert(context, testSig);
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.notifications_active_rounded),
        label: const Text(
          'Test Alert',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () => _loadData(),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'DERIV EDGE RADAR • v1.0.4',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Price Action M5',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final testSig = TradeSignal(
                                  id: 'test_${DateTime.now().millisecondsSinceEpoch}',
                                  symbol: 'R_25',
                                  pattern: 'Hammer',
                                  direction: 'BUY',
                                  entry: 2745.50,
                                  sl: 2738.20,
                                  tp: 2760.10,
                                  rr: 2.0,
                                  timestamp: 'Just Now',
                                  status: 'OPEN',
                                  resultR: 0.0,
                                  isLive: true,
                                );
                                NotificationService.triggerAlert(context, testSig);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderLight, width: 0.8),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: AppTheme.primary,
                                  size: 16,
                                ),
                              ),
                            ),
                            PulseBadge(
                              isOnline: _isOnline,
                              label: _isOnline ? 'CLOUD ACTIVE' : 'RECONNECTING',
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Active Pairs Status Pill Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPairStatus('R_25', 'Active - 2s Poll', AppTheme.primary),
                          Container(width: 1, height: 24, color: AppTheme.border),
                          _buildPairStatus('R_75', 'Active - 2s Poll', AppTheme.primary),
                          Container(width: 1, height: 24, color: AppTheme.border),
                          _buildPairStatus('TIMEFRAME', 'M5 Candlesticks', AppTheme.textSecondary),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section: Active Trade Setups
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'LIVE ACTIVE TRADES',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: activeSignals.isNotEmpty
                                    ? AppTheme.primary.withValues(alpha: 0.15)
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${activeSignals.length}',
                                style: TextStyle(
                                  color: activeSignals.isNotEmpty
                                      ? AppTheme.primary
                                      : AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_liveSignals.isEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showBenchmarkPreview = !_showBenchmarkPreview;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _showBenchmarkPreview
                                    ? AppTheme.primary.withValues(alpha: 0.15)
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _showBenchmarkPreview
                                      ? AppTheme.primary.withValues(alpha: 0.4)
                                      : AppTheme.borderLight,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showBenchmarkPreview ? Icons.visibility_off : Icons.visibility,
                                    size: 12,
                                    color: _showBenchmarkPreview ? AppTheme.primary : AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showBenchmarkPreview ? 'Hide Demo' : 'View Demo',
                                    style: TextStyle(
                                      color: _showBenchmarkPreview ? AppTheme.primary : AppTheme.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // If active trades exist, show them
                    if (activeSignals.isNotEmpty)
                      ...activeSignals.map((s) => SignalCard(signal: s))
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border, width: 1),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.radar_rounded,
                              size: 36,
                              color: AppTheme.primary.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Live Cloud Radar Scanning',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'No open positions right now. The bot is actively polling Deriv market ticks every 2 seconds.\n\nWhen a confirmed Hammer (70% win rate) or Morning Star (53% win rate) closes on the M5 bar, your real-time signal card will appear here instantly.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                final testSig = TradeSignal(
                                  id: 'test_${DateTime.now().millisecondsSinceEpoch}',
                                  symbol: 'R_25',
                                  pattern: 'Hammer',
                                  direction: 'BUY',
                                  entry: 2745.50,
                                  sl: 2738.20,
                                  tp: 2760.10,
                                  rr: 2.0,
                                  timestamp: 'Just Now',
                                  status: 'OPEN',
                                  resultR: 0.0,
                                  isLive: true,
                                );
                                NotificationService.triggerAlert(context, testSig);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.notifications_active_rounded,
                                      size: 15,
                                      color: AppTheme.primary,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Test Sound & Vibration Alert',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Section: Recent Live Signals OR Benchmark Demo Preview
                    if (recentClosed.isNotEmpty) ...[
                      const Text(
                        'RECENT LIVE SIGNALS',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...recentClosed.map((s) => SignalCard(signal: s)),
                    ] else if (_showBenchmarkPreview) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'HISTORICAL BENCHMARK',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Demo Reference',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...benchmarkList.map((s) => SignalCard(signal: s)),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPairStatus(String symbol, String status, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          symbol,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          status,
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
