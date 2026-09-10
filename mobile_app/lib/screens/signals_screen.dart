import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trade_signal.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pulse_badge.dart';
import '../widgets/signal_card.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  List<TradeSignal> _signals = [];
  bool _isLoading = true;
  bool _isOnline = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 20 seconds
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _loadData(silent: true));
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
    final signals = await ApiService.fetchSignals();

    if (mounted) {
      setState(() {
        _isOnline = online;
        _signals = signals;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSignals = _signals.where((s) => s.isOpen).toList();
    final recentClosed = _signals.where((s) => !s.isOpen).take(6).toList();

    return Scaffold(
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SIGNAL RADAR',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Price Action M5',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        PulseBadge(
                          isOnline: _isOnline,
                          label: _isOnline ? 'CLOUD ACTIVE' : 'RECONNECTING',
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

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
                      children: [
                        const Text(
                          'ACTIVE TRADES',
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
                    const SizedBox(height: 12),

                    if (activeSignals.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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
                              color: AppTheme.textMuted.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Scanning Market Feed',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'No open positions. Awaiting high-probability Hammer or Morning Star on M5 candle close.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...activeSignals.map((s) => SignalCard(signal: s)),

                    const SizedBox(height: 28),

                    // Section: Recent Triggered Signals
                    const Text(
                      'RECENT SIGNALS',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (recentClosed.isEmpty)
                      const Center(
                        child: Text(
                          'No recent signals',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      )
                    else
                      ...recentClosed.map((s) => SignalCard(signal: s)),
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
