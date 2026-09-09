"""
stats.py -- Live signal log analyzer
=====================================
Reads signals_log.csv (produced by signal_bot.py) and prints a
performance summary. Optionally accepts a --outcome-col flag if you
have manually annotated outcomes in the CSV.

Usage
-----
  python stats.py                          # reads signals_log.csv in same dir
  python stats.py --file my_signals.csv
  python stats.py --outcome-col outcome    # if you added an outcome column manually

Manually tracking outcomes
--------------------------
Open signals_log.csv in Excel / LibreOffice and add a column called
"outcome" with values: WIN, LOSS, or SKIP (trades you chose not to take).
Then run:  python stats.py --outcome-col outcome
"""

import argparse
import csv
import os
import sys
from collections import defaultdict


DEFAULT_LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "signals_log.csv")


def load_signals(path: str, outcome_col: str | None) -> list:
    if not os.path.isfile(path):
        print(f"[Error] File not found: {path}")
        sys.exit(1)

    rows = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "time_utc":    row.get("time_utc", ""),
                "symbol":      row.get("symbol", "?"),
                "signal":      row.get("signal", "?"),
                "pattern":     row.get("pattern", "?"),
                "htf_trend":   row.get("htf_trend", "?"),
                "entry":       float(row.get("entry", 0) or 0),
                "sl":          float(row.get("sl", 0) or 0),
                "tp":          float(row.get("tp", 0) or 0),
                "risk_reward": float(row.get("risk_reward", 0) or 0),
                "outcome":     row.get(outcome_col, "").strip().upper() if outcome_col else None,
            })
    return rows


def print_stats(rows: list, outcome_col: str | None) -> None:
    if not rows:
        print("No signals found in the log.")
        return

    total = len(rows)
    by_symbol  = defaultdict(int)
    by_signal  = defaultdict(int)
    by_pattern = defaultdict(int)
    by_trend   = defaultdict(int)

    for r in rows:
        by_symbol[r["symbol"]] += 1
        by_signal[r["signal"]] += 1
        by_pattern[r["pattern"]] += 1
        by_trend[r["htf_trend"]] += 1

    avg_rr = sum(r["risk_reward"] for r in rows) / total

    print()
    print("=" * 58)
    print("  SIGNAL LOG SUMMARY")
    print("=" * 58)
    print(f"  Log file     : {DEFAULT_LOG}")
    print(f"  Total signals: {total}")
    print(f"  Avg R:R      : {avg_rr:.2f}")
    print()
    print("  -- By Symbol --")
    for sym, n in sorted(by_symbol.items(), key=lambda x: -x[1]):
        print(f"    {sym:<20} {n:>5} signals")

    print()
    print("  -- By Direction --")
    for sig, n in sorted(by_signal.items()):
        print(f"    {sig:<10} {n:>5} signals")

    print()
    print("  -- By Pattern --")
    for pat, n in sorted(by_pattern.items(), key=lambda x: -x[1]):
        print(f"    {pat:<24} {n:>5} signals")

    print()
    print("  -- By HTF Trend --")
    for tr, n in sorted(by_trend.items()):
        print(f"    {tr:<10} {n:>5} signals")

    # Outcome analysis (only if outcome column was provided)
    if outcome_col:
        print()
        print("  -- Outcome Analysis (manual annotations) --")
        closed = [r for r in rows if r["outcome"] in ("WIN", "LOSS")]
        skipped = [r for r in rows if r["outcome"] == "SKIP"]
        wins    = [r for r in closed if r["outcome"] == "WIN"]
        losses  = [r for r in closed if r["outcome"] == "LOSS"]
        unknown = [r for r in rows if r["outcome"] not in ("WIN", "LOSS", "SKIP")]

        if not closed:
            print("    No WIN/LOSS outcomes found. Add an 'outcome' column to your CSV.")
        else:
            win_rate     = len(wins) / len(closed) * 100
            gross_profit = sum(r["risk_reward"] for r in wins)
            gross_loss   = len(losses)
            pf           = gross_profit / gross_loss if gross_loss else float("inf")
            expectancy   = (gross_profit - gross_loss) / len(closed)

            print(f"    Closed trades : {len(closed)}")
            print(f"    Wins          : {len(wins)}")
            print(f"    Losses        : {len(losses)}")
            print(f"    Skipped       : {len(skipped)}")
            print(f"    Unannotated   : {len(unknown)}")
            print(f"    Win Rate      : {win_rate:.1f}%")
            print(f"    Profit Factor : {pf:.2f}")
            print(f"    Expectancy    : {expectancy:+.3f} R per trade")

            if closed:
                print()
                print(f"    {'Pattern':<24} {'Total':>6} {'Wins':>5} {'Losses':>7} {'Win%':>6}")
                print(f"    {'-'*24} {'-'*6} {'-'*5} {'-'*7} {'-'*6}")
                pat_stats = defaultdict(lambda: {"W": 0, "L": 0})
                for r in closed:
                    pat_stats[r["pattern"]]["W" if r["outcome"] == "WIN" else "L"] += 1
                for pat, s in sorted(pat_stats.items()):
                    t   = s["W"] + s["L"]
                    wr  = s["W"] / t * 100 if t else 0
                    print(f"    {pat:<24} {t:>6} {s['W']:>5} {s['L']:>7} {wr:>5.1f}%")

    print("=" * 58)
    print()


def parse_args():
    p = argparse.ArgumentParser(description="Analyze signals_log.csv from signal_bot.py")
    p.add_argument("--file",        default=DEFAULT_LOG,
                   help=f"Path to CSV log file (default: {DEFAULT_LOG})")
    p.add_argument("--outcome-col", default=None, metavar="COL",
                   help="Name of a column in the CSV containing WIN/LOSS/SKIP outcomes")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    rows = load_signals(args.file, args.outcome_col)
    print_stats(rows, args.outcome_col)
