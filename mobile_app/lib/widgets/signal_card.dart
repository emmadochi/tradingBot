import 'package:flutter/material.dart';
import '../models/trade_signal.dart';
import '../theme/app_theme.dart';
import 'lot_calculator_sheet.dart';

class SignalCard extends StatelessWidget {
  final TradeSignal signal;

  const SignalCard({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final isBuy = signal.direction.toUpperCase() == 'BUY';
    final dirColor = isBuy ? AppTheme.success : AppTheme.error;

    // Status styling
    Color statusColor;
    Color statusBg;
    String statusText;

    if (signal.isOpen) {
      statusColor = AppTheme.primary;
      statusBg = AppTheme.primary.withValues(alpha: 0.12);
      statusText = 'ACTIVE';
    } else if (signal.isWin) {
      statusColor = AppTheme.success;
      statusBg = AppTheme.success.withValues(alpha: 0.12);
      statusText = '+${signal.resultR.toStringAsFixed(1)} R WIN';
    } else if (signal.isLoss) {
      statusColor = AppTheme.error;
      statusBg = AppTheme.error.withValues(alpha: 0.12);
      statusText = '${signal.resultR.toStringAsFixed(1)} R LOSS';
    } else {
      statusColor = AppTheme.textMuted;
      statusBg = AppTheme.border;
      statusText = signal.status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: signal.isOpen
              ? AppTheme.primary.withValues(alpha: 0.35)
              : AppTheme.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              // Symbol badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderLight, width: 0.8),
                ),
                child: Text(
                  signal.symbol,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Direction Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: dirColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBuy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 13,
                      color: dirColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      signal.direction,
                      style: TextStyle(
                        color: dirColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Pattern Tag
              Text(
                signal.pattern,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              // Live vs Benchmark tag
              if (!signal.isLive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderLight, width: 0.7),
                  ),
                  child: const Text(
                    'BENCHMARK',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Price Metrics Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPriceColumn('ENTRY', _formatPrice(signal.entry), AppTheme.textPrimary),
                _buildPriceColumn('STOP LOSS', _formatPrice(signal.sl), AppTheme.error),
                _buildPriceColumn('TAKE PROFIT', _formatPrice(signal.tp), AppTheme.success),
                _buildPriceColumn('R:R', '1 : ${signal.rr.toStringAsFixed(1)}', AppTheme.primary),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Footer Row with Calculate Lot Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                signal.timestamp,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
              GestureDetector(
                onTap: () => LotCalculatorSheet.show(context, signal),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.calculate_rounded, size: 13, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text(
                        'Calculate Lot',
                        style: TextStyle(
                          color: AppTheme.primary,
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
        ],
      ),
    );
  }

  Widget _buildPriceColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    if (price >= 10000) {
      return price.toStringAsFixed(1);
    } else if (price >= 100) {
      return price.toStringAsFixed(2);
    } else {
      return price.toStringAsFixed(3);
    }
  }
}
