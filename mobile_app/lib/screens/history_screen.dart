import 'package:flutter/material.dart';
import '../models/trade_signal.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TradeSignal> _signals = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL'; // 'ALL', 'WINS', 'LOSSES', 'OPEN'
  String _selectedSymbol = 'ALL'; // 'ALL', 'R_25', 'R_75'

  @override
  void initState() {
    super.initState();
    _loadSignals();
  }

  Future<void> _loadSignals() async {
    setState(() => _isLoading = true);
    final signals = await ApiService.fetchSignals();
    if (mounted) {
      setState(() {
        _signals = signals;
        _isLoading = false;
      });
    }
  }

  List<TradeSignal> get _filteredSignals {
    return _signals.where((s) {
      final matchesFilter = switch (_selectedFilter) {
        'WINS' => s.isWin,
        'LOSSES' => s.isLoss,
        'OPEN' => s.isOpen,
        _ => true,
      };

      final matchesSymbol = _selectedSymbol == 'ALL' || s.symbol == _selectedSymbol;

      return matchesFilter && matchesSymbol;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSignals;
    final totalWins = filtered.where((s) => s.isWin).length;
    final totalLosses = filtered.where((s) => s.isLoss).length;
    final totalClosed = totalWins + totalLosses;
    final winRate = totalClosed > 0 ? (totalWins / totalClosed) * 100 : 0.0;
    final netR = filtered.fold<double>(0.0, (acc, s) => acc + s.resultR);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: _loadSignals,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TRANSPARENT AUDIT',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Trade Journal',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      // Symbol Dropdown Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border, width: 1),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSymbol,
                            dropdownColor: AppTheme.surface,
                            icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted, size: 18),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text('All Symbols')),
                              DropdownMenuItem(value: 'R_25', child: Text('R_25 Only')),
                              DropdownMenuItem(value: 'R_75', child: Text('R_75 Only')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedSymbol = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All (${_signals.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('WINS', 'Wins (${_signals.where((s) => s.isWin).length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('LOSSES', 'Losses (${_signals.where((s) => s.isLoss).length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('OPEN', 'Open (${_signals.where((s) => s.isOpen).length})'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filter Summary Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filtered.length} Trades Shown',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Win Rate: ${winRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: netR >= 0
                                ? AppTheme.success.withValues(alpha: 0.12)
                                : AppTheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            netR >= 0 ? '+${netR.toStringAsFixed(1)} R' : '${netR.toStringAsFixed(1)} R',
                            style: TextStyle(
                              color: netR >= 0 ? AppTheme.success : AppTheme.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // List of Signals
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  alignment: Alignment.center,
                  child: const Text(
                    'No trades match this filter.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                )
              else
                ...filtered.map((s) => SignalCard(signal: s)),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.background : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
