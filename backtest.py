"""
backtest.py -- Historical backtest for signal_bot.py strategy
=============================================================
Fetches candle history from Deriv's public API and replays it
through the exact same strategy logic in signal_bot.py to
estimate edge before running live.

Usage
-----
  python backtest.py                          # default: R_25, 1h/5m, last 5000 LTF candles
  python backtest.py --symbol 1HZ75V
  python backtest.py --symbol R_25 --htf 14400 --ltf 900
  python backtest.py --symbol R_25 --ltf-count 2000

Output
------
  Console: full performance report
  backtest_results.csv: one row per simulated trade

IMPORTANT: Synthetic indices are RNG-based. A good backtest on synthetics
does NOT prove real-market edge. Use this to validate the signal logic and
understand how often signals fire, not as proof of profitability.
"""

import argparse
import asyncio
import csv
import json
import os
import sys
from collections import defaultdict

import numpy as np
import pandas as pd
import websockets

# -- Import strategy functions directly from signal_bot (no duplication) ------
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from signal_bot import (
    ATR_PERIOD,
    HTF_CANDLE_COUNT,
    HTF_GRANULARITY,
    LTF_CANDLE_COUNT,
    LTF_GRANULARITY,
    MIN_RISK_REWARD,
    SR_PROXIMITY_PCT,
    SL_BUFFER_ATR_MULT,
    SIGNAL_COOLDOWN_SECONDS,
    SIGNAL_MIN_BODY_RATIO,
    SR_MAX_LEVEL_TOUCHES,
    ENABLED_PATTERNS,
    SWING_LOOKBACK,
    WS_URL,
    atr,
    cluster_levels,
    detect_pattern,
    determine_trend,
    find_swings,
    nearest_above,
    nearest_below,
    pct_distance,
)

OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backtest_results.csv")


# -- Deriv API helpers ---------------------------------------------------------

async def fetch_candles(symbol: str, granularity: int, count: int) -> pd.DataFrame:
    """Fetch up to `count` historical candles for a symbol from Deriv."""
    async with websockets.connect(WS_URL) as ws:
        await ws.send(json.dumps({
            "ticks_history": symbol,
            "adjust_start_time": 1,
            "count": count,
            "end": "latest",
            "style": "candles",
            "granularity": granularity,
        }))
        resp = json.loads(await ws.recv())

    if "error" in resp:
        raise RuntimeError(f"API error for {symbol}: {resp['error']['message']}")

    candles = resp.get("candles", [])
    df = pd.DataFrame([
        {
            "epoch": c["epoch"],
            "open":  float(c["open"]),
            "high":  float(c["high"]),
            "low":   float(c["low"]),
            "close": float(c["close"]),
        }
        for c in candles
    ])
    return df.reset_index(drop=True)


# -- Trade simulation ----------------------------------------------------------

def simulate_outcome(signal: str, entry: float, sl: float, tp: float,
                     future_candles: pd.DataFrame) -> str:
    """
    Walk forward through future candles.
    Returns 'WIN', 'LOSS', or 'OPEN' (neither hit within the window).
    """
    for _, row in future_candles.iterrows():
        if signal == "BUY":
            if row["low"] <= sl:
                return "LOSS"
            if row["high"] >= tp:
                return "WIN"
        else:  # SELL
            if row["high"] >= sl:
                return "LOSS"
            if row["low"] <= tp:
                return "WIN"
    return "OPEN"


# -- Core backtest logic -------------------------------------------------------

def run_backtest(htf_df: pd.DataFrame, ltf_df: pd.DataFrame) -> list:
    """
    Replay LTF candles chronologically. At each bar:
      1. Use HTF candles up to that point for trend + S/R.
      2. Look for a signal on the last 3 LTF candles.
      3. If found, simulate outcome on the next 50 LTF candles.
    """
    ltf_df = ltf_df.copy()
    ltf_df["atr"] = atr(ltf_df, ATR_PERIOD)

    trades = []
    last_signal_epoch = None
    level_touches: dict = {}   # tracks level freshness across the replay
    warm_up = max(ATR_PERIOD, 5) + 3

    for i in range(warm_up, len(ltf_df)):
        curr_epoch = ltf_df["epoch"].iloc[i]

        # HTF context up to current LTF bar
        htf_slice = htf_df[htf_df["epoch"] <= curr_epoch]
        if len(htf_slice) < SWING_LOOKBACK * 2 + 2:
            continue

        swing_highs, swing_lows = find_swings(htf_slice)
        resistance_levels = cluster_levels(swing_highs)
        support_levels    = cluster_levels(swing_lows)
        trend             = determine_trend(htf_slice, swing_highs, swing_lows)

        if not support_levels and not resistance_levels:
            continue

        # LTF signal evaluation
        ltf_slice = ltf_df.iloc[max(0, i - LTF_CANDLE_COUNT): i + 1].copy()
        curr      = ltf_slice.iloc[-1]

        # Filter 1: Only enabled high-winrate patterns
        pattern, direction = detect_pattern(ltf_slice.tail(3))
        if not direction or pattern not in ENABLED_PATTERNS:
            continue

        # Filter 2: No RANGE trend — only trade clear UP or DOWN
        if trend == "RANGE":
            continue

        # Filter 3: Strong body confirmation (for multi-candle patterns; Hammers/Shooting Stars inherently have small bodies)
        if pattern not in ("Hammer", "Shooting Star"):
            sig_candle = ltf_slice.iloc[-1]
            body = abs(sig_candle["close"] - sig_candle["open"])
            rng  = sig_candle["high"] - sig_candle["low"]
            if rng > 0 and (body / rng) < SIGNAL_MIN_BODY_RATIO:
                continue

        # Enforce signal cooldown
        if last_signal_epoch and (curr_epoch - last_signal_epoch < SIGNAL_COOLDOWN_SECONDS):
            continue

        price      = curr["close"]
        support    = nearest_below(support_levels, price)
        resistance = nearest_above(resistance_levels, price)

        signal = None
        level_used = None
        if (direction == "BUY" and support is not None
                and pct_distance(price, support) <= SR_PROXIMITY_PCT
                and curr["close"] >= support * 0.9995
                and ltf_slice["low"].tail(3).min() <= support * (1 + SR_PROXIMITY_PCT / 100)
                and trend == "UP"):
            signal, level_used = "BUY", support
        elif (direction == "SELL" and resistance is not None
                and pct_distance(price, resistance) <= SR_PROXIMITY_PCT
                and curr["close"] <= resistance * 1.0005
                and ltf_slice["high"].tail(3).max() >= resistance * (1 - SR_PROXIMITY_PCT / 100)
                and trend == "DOWN"):
            signal, level_used = "SELL", resistance

        if not signal:
            continue

        # Filter 4: Fresh level only
        level_key = round(level_used, 2)
        if level_touches.get(level_key, 0) >= SR_MAX_LEVEL_TOUCHES:
            continue
        level_touches[level_key] = level_touches.get(level_key, 0) + 1

        last_signal_epoch = curr_epoch


        # Compute entry / SL / TP
        buf          = curr["atr"] * SL_BUFFER_ATR_MULT
        entry        = price
        pattern_low  = ltf_slice["low"].tail(3).min()
        pattern_high = ltf_slice["high"].tail(3).max()

        if signal == "BUY":
            sl   = min(level_used, pattern_low) - buf
            risk = entry - sl
            tgt  = nearest_above(resistance_levels, entry)
            tp   = (tgt if tgt and risk > 0 and (tgt - entry) / risk >= MIN_RISK_REWARD
                    else entry + risk * MIN_RISK_REWARD)
        else:
            sl   = max(level_used, pattern_high) + buf
            risk = sl - entry
            tgt  = nearest_below(support_levels, entry)
            tp   = (tgt if tgt and risk > 0 and (entry - tgt) / risk >= MIN_RISK_REWARD
                    else entry - risk * MIN_RISK_REWARD)

        if risk <= 0:
            continue

        rr = abs(tp - entry) / risk

        # Simulate outcome on the next 50 LTF candles
        future  = ltf_df.iloc[i + 1: i + 51]
        outcome = simulate_outcome(signal, entry, sl, tp, future)

        trades.append({
            "epoch":       curr_epoch,
            "signal":      signal,
            "pattern":     pattern,
            "htf_trend":   trend,
            "level_used":  round(level_used, 6),
            "entry":       round(entry, 6),
            "sl":          round(sl, 6),
            "tp":          round(tp, 6),
            "risk_reward": round(rr, 3),
            "outcome":     outcome,
        })

    return trades


# -- Reporting -----------------------------------------------------------------

def print_report(symbol: str, trades: list) -> None:
    if not trades:
        print(f"\n[{symbol}] No signals generated.")
        print("  Try relaxing SR_PROXIMITY_PCT or fetching more candles.")
        return

    closed = [t for t in trades if t["outcome"] != "OPEN"]
    wins   = [t for t in closed if t["outcome"] == "WIN"]
    losses = [t for t in closed if t["outcome"] == "LOSS"]
    open_  = [t for t in trades if t["outcome"] == "OPEN"]

    win_rate     = len(wins) / len(closed) * 100 if closed else 0
    avg_rr       = sum(t["risk_reward"] for t in trades) / len(trades)
    gross_profit = sum(t["risk_reward"] for t in wins)
    gross_loss   = len(losses)
    pf           = gross_profit / gross_loss if gross_loss else float("inf")
    expectancy   = (gross_profit - gross_loss) / len(closed) if closed else 0

    # Max consecutive losses
    max_consec = cur = 0
    for t in closed:
        cur = cur + 1 if t["outcome"] == "LOSS" else 0
        max_consec = max(max_consec, cur)

    # Max drawdown in R
    equity = peak = max_dd = 0.0
    for t in closed:
        equity += t["risk_reward"] if t["outcome"] == "WIN" else -1
        peak    = max(peak, equity)
        max_dd  = max(max_dd, peak - equity)

    # Per-pattern breakdown
    by_pattern = defaultdict(lambda: {"W": 0, "L": 0, "total": 0})
    for t in closed:
        bp = by_pattern[t["pattern"]]
        bp["total"] += 1
        bp["W" if t["outcome"] == "WIN" else "L"] += 1

    print()
    print("=" * 62)
    print(f"  BACKTEST REPORT -- {symbol}")
    print("=" * 62)
    print(f"  Total signals      : {len(trades):>6}")
    print(f"  Closed trades      : {len(closed):>6}  (TP or SL hit in 50 bars)")
    print(f"  Open  (timeout)    : {len(open_):>6}  (neither hit in 50 bars)")
    print(f"  Wins               : {len(wins):>6}")
    print(f"  Losses             : {len(losses):>6}")
    print(f"  Win Rate           : {win_rate:>6.1f}%")
    print(f"  Avg R:R on signals : {avg_rr:>6.2f}")
    print(f"  Profit Factor      : {pf:>6.2f}  (> 1.0 = net profitable)")
    print(f"  Expectancy         : {expectancy:>+6.3f} R per closed trade")
    print(f"  Max Consec Losses  : {max_consec:>6}")
    print(f"  Max Drawdown       : {max_dd:>6.2f} R")
    print()
    print(f"  {'Pattern':<24} {'Total':>6} {'Wins':>5} {'Losses':>7} {'Win%':>6}")
    print(f"  {'-'*24} {'-'*6} {'-'*5} {'-'*7} {'-'*6}")
    for pat, s in sorted(by_pattern.items()):
        wr = s["W"] / s["total"] * 100 if s["total"] else 0
        print(f"  {pat:<24} {s['total']:>6} {s['W']:>5} {s['L']:>7} {wr:>5.1f}%")
    print("=" * 62)
    print()


def save_results(symbol: str, trades: list) -> None:
    if not trades:
        return
    file_exists = os.path.isfile(OUTPUT_FILE)
    with open(OUTPUT_FILE, "a", newline="") as f:
        fieldnames = ["symbol"] + list(trades[0].keys())
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if not file_exists:
            writer.writeheader()
        for t in trades:
            writer.writerow({"symbol": symbol, **t})
    print(f"  Results appended to: {OUTPUT_FILE}")


# -- Entry point ---------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(
        description="Backtest the signal_bot.py strategy on Deriv historical data."
    )
    p.add_argument("--symbol",    default="R_25",
                   help="Deriv symbol to backtest (default: R_25)")
    p.add_argument("--htf",       type=int, default=HTF_GRANULARITY, metavar="SECS",
                   help=f"HTF granularity in seconds (default: {HTF_GRANULARITY})")
    p.add_argument("--ltf",       type=int, default=LTF_GRANULARITY, metavar="SECS",
                   help=f"LTF granularity in seconds (default: {LTF_GRANULARITY})")
    p.add_argument("--htf-count", type=int, default=HTF_CANDLE_COUNT, metavar="N",
                   help=f"HTF candles to fetch (default: {HTF_CANDLE_COUNT})")
    p.add_argument("--ltf-count", type=int, default=5000, metavar="N",
                   help="LTF candles to backtest over (default: 5000)")
    return p.parse_args()


async def async_main():
    args = parse_args()

    # Ensure HTF history spans the full time period covered by LTF candles
    required_htf = int(args.ltf_count * args.ltf / args.htf) + 100
    htf_count = max(args.htf_count, required_htf)

    print(f"\nFetching data for {args.symbol} ...")
    print(f"  HTF: {args.htf}s x {htf_count} candles")
    print(f"  LTF: {args.ltf}s x {args.ltf_count} candles")

    htf_df = await fetch_candles(args.symbol, args.htf, htf_count)
    ltf_df = await fetch_candles(args.symbol, args.ltf, args.ltf_count)

    print(f"  HTF candles received : {len(htf_df)}")
    print(f"  LTF candles received : {len(ltf_df)}")
    print("Running backtest ...")

    trades = run_backtest(htf_df, ltf_df)
    print_report(args.symbol, trades)
    save_results(args.symbol, trades)


if __name__ == "__main__":
    try:
        asyncio.run(async_main())
    except KeyboardInterrupt:
        print("\nCancelled.")
