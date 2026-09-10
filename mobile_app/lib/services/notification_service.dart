import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/trade_signal.dart';
import '../theme/app_theme.dart';

class NotificationService {
  static final AudioPlayer _player = AudioPlayer();
  static final Set<String> _seenSignalIds = {};

  /// Plays the loud, crisp trading chime through the device speakers
  static Future<void> playAlertSound() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/alert.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('Audio error: $e');
      SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Check new signals, and trigger sound & haptic notification for any new ones
  static void checkForNewSignals(BuildContext context, List<TradeSignal> signals) {
    for (final s in signals) {
      if (!_seenSignalIds.contains(s.id)) {
        _seenSignalIds.add(s.id);

        // Only ring sound/vibration for live signals (not historical backtest demo)
        if (s.isLive) {
          triggerAlert(context, s);
        }
      }
    }
  }

  /// Triggers audible chime, heavy haptic vibration, and in-app banner
  static Future<void> triggerAlert(BuildContext context, TradeSignal signal) async {
    try {
      // 1. Play crisp audio chime asset through speaker at 100% volume
      await playAlertSound();

      // 2. Heavy dual-pulse haptic vibration
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (_) {}

    // 3. Show high-priority in-app alert banner
    if (context.mounted) {
      final isBuy = signal.direction == 'BUY';
      final color = isBuy ? AppTheme.success : AppTheme.error;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: AppTheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color, width: 1.2),
          ),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBuy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEW M5 SIGNAL: ${signal.direction} ${signal.symbol}',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${signal.pattern} @ ${signal.entry} (SL: ${signal.sl}, TP: ${signal.tp})',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
