import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_signals_app/models/trade_signal.dart';
import 'package:trading_signals_app/widgets/stat_card.dart';
import 'package:trading_signals_app/widgets/signal_card.dart';
import 'package:trading_signals_app/theme/app_theme.dart';

void main() {
  testWidgets('StatCard renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            title: 'Win Rate',
            value: '70.0%',
            subtitle: '14W / 6L',
          ),
        ),
      ),
    );

    expect(find.text('WIN RATE'), findsOneWidget);
    expect(find.text('70.0%'), findsOneWidget);
    expect(find.text('14W / 6L'), findsOneWidget);
  });

  testWidgets('SignalCard renders trade details correctly', (WidgetTester tester) async {
    final signal = TradeSignal(
      id: 'test_01',
      symbol: 'R_25',
      pattern: 'Hammer',
      direction: 'BUY',
      entry: 2134.50,
      sl: 2129.80,
      tp: 2143.90,
      rr: 2.0,
      timestamp: '2026-09-10 00:15 UTC',
      status: 'OPEN',
      resultR: 0.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SignalCard(signal: signal),
        ),
      ),
    );

    expect(find.text('R_25'), findsOneWidget);
    expect(find.text('Hammer'), findsOneWidget);
    expect(find.text('BUY'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('1 : 2.0'), findsOneWidget);
  });
}
