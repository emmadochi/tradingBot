# Deriv Synthetic Index Signal Bot — Top-Down Price Action

Watches Volatility 25 Index (`R_25`) and Volatility 75 (1s) Index (`1HZ75V`)
and prints/logs BUY/SELL signals with Entry, SL, and TP. **It does not place
trades for you** — you execute manually on Deriv.

## Strategy: Top-Down Price Action
1. **Higher timeframe (1h, configurable)** — determines trend direction from
   swing structure (higher highs/higher lows = uptrend, etc., with an
   EMA(50) fallback when structure is unclear) and maps support/resistance
   zones from clustered swing highs/lows.
2. **Lower timeframe (5m, configurable)** — waits for price to reach one of
   those HTF zones, then looks for a reversal candlestick pattern in the
   direction of the HTF trend:
   - Bullish/Bearish Engulfing
   - Hammer / Shooting Star
   - Morning Star / Evening Star
3. **Entry** = price at the pattern's close. **SL** = beyond the S/R level or
   pattern extreme (whichever is further), plus an ATR buffer. **TP** = the
   next opposing S/R zone, or a 1:1.5 risk-reward fallback if no zone
   qualifies.

Only trades **with** the HTF trend at support (for buys) or resistance (for
sells) — no counter-trend signals, and no signals when price isn't actually
near a mapped zone.

## Setup
```bash
pip install -r requirements.txt
python signal_bot.py
```

Uses Deriv's public demo `app_id=1089` by default so it works out of the box.
For your own production `app_id`, register one free at https://api.deriv.com
and paste it into the `APP_ID` variable in `signal_bot.py`.

## Output
- Console: prints each new signal with the pattern, HTF trend, and the S/R
  level it triggered from
- `signals_log.csv`: running log of every signal (time, symbol, signal,
  pattern, HTF trend, level, entry, SL, TP, risk:reward)

## Customizing
All in the `CONFIG` block at the top of `signal_bot.py`:
- `SYMBOLS` — add more Deriv symbols (e.g. `R_10`, `R_50`, `R_100`, `1HZ100V`)
- `HTF_GRANULARITY` / `LTF_GRANULARITY` — timeframes for trend/S-R vs entry
  trigger (seconds: 60=1m, 300=5m, 900=15m, 3600=1h, 14400=4h)
- `SWING_LOOKBACK` — how many bars either side confirm a swing point
  (higher = fewer, more significant levels)
- `SR_CLUSTER_PCT` — how close swing prices must be to merge into one zone
- `SR_PROXIMITY_PCT` — how close price must get to a zone to trigger a check
- `MIN_RISK_REWARD` — minimum reward:risk enforced on every signal
- `SL_BUFFER_ATR_MULT` — extra breathing room added to every SL

## Important
Synthetic indices are random-walk-based instruments. This bot applies price
action rules consistently — it does not predict outcomes with certainty.
Always risk only what you can afford to lose, and consider backtesting or
paper trading before using signals with real money.
