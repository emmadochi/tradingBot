import asyncio
import json
import os
import sys
import time
from datetime import datetime, timezone
import pandas as pd
import websockets

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from signal_bot import (
    WS_URL,
    HTF_GRANULARITY,
    LTF_GRANULARITY,
    atr,
    determine_trend,
    find_swings,
    cluster_levels,
    nearest_above,
    nearest_below,
    pct_distance,
    detect_pattern,
    ENABLED_PATTERNS,
    MIN_RISK_REWARD,
    SL_BUFFER_ATR_MULT,
    SR_PROXIMITY_PCT,
    SIGNAL_COOLDOWN_SECONDS,
)

async def fetch_candles(symbol: str, granularity: int, count: int) -> pd.DataFrame:
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
        if "candles" not in resp:
            print(f"Error fetching {symbol}: {resp}")
            return pd.DataFrame()
        df = pd.DataFrame(resp["candles"])
        df["epoch"] = pd.to_datetime(df["epoch"], unit="s", utc=True)
        df.rename(columns={"epoch": "time"}, inplace=True)
        for col in ["open", "high", "low", "close"]:
            df[col] = df[col].astype(float)
        return df

async def get_signals_for_symbol(symbol: str):
    print(f"Fetching candles for {symbol}...")
    ltf_df = await fetch_candles(symbol, LTF_GRANULARITY, 1500)
    htf_df = await fetch_candles(symbol, HTF_GRANULARITY, 300)
    
    if ltf_df.empty or htf_df.empty:
        return []

    signals = []
    last_signal_time = 0

    for i in range(50, len(ltf_df) - 10):
        current_ltf = ltf_df.iloc[: i + 1]
        candle = current_ltf.iloc[-1]
        candle_time = candle["time"]
        candle_ts = candle_time.timestamp()

        # Stop at end of yesterday (2026-09-09 23:59:59 UTC)
        if candle_time.date() > datetime(2026, 9, 9).date():
            continue

        if candle_ts - last_signal_time < SIGNAL_COOLDOWN_SECONDS:
            continue

        current_htf = htf_df[htf_df["time"] <= candle_time]
        if len(current_htf) < 20:
            continue

        trend = determine_trend(current_htf)
        highs, lows = find_swings(current_htf)
        supports = cluster_levels(lows)
        resistances = cluster_levels(highs)

        c_atr = atr(current_ltf)
        if c_atr is None:
            continue

        c1, c2, c3 = current_ltf.iloc[-3], current_ltf.iloc[-2], current_ltf.iloc[-1]
        pattern = detect_pattern(c1, c2, c3, c_atr)
        if pattern not in ENABLED_PATTERNS:
            continue

        near_sup = nearest_below(supports, candle["close"])
        if not near_sup:
            continue
        dist = pct_distance(candle["close"], near_sup)
        if dist > SR_PROXIMITY_PCT:
            continue

        entry_price = candle["close"]
        sl = min(c1["low"], c2["low"], c3["low"]) - (SL_BUFFER_ATR_MULT * c_atr)
        risk = entry_price - sl
        if risk <= 0:
            continue

        near_res = nearest_above(resistances, entry_price)
        tp = near_res if near_res and (near_res - entry_price) >= (MIN_RISK_REWARD * risk) else entry_price + (MIN_RISK_REWARD * risk)
        reward = tp - entry_price
        rr = reward / risk
        if rr < MIN_RISK_REWARD:
            continue

        # Simulate outcome forward
        outcome = "OPEN"
        result_r = 0.0
        exit_price = None
        exit_time = None

        future_candles = ltf_df.iloc[i + 1 :]
        for _, fc in future_candles.iterrows():
            if fc["low"] <= sl:
                outcome = "LOSS"
                result_r = -1.0
                exit_price = sl
                exit_time = fc["time"].strftime("%Y-%m-%d %H:%M:%S UTC")
                break
            elif fc["high"] >= tp:
                outcome = "WIN"
                result_r = round(rr, 1)
                exit_price = tp
                exit_time = fc["time"].strftime("%Y-%m-%d %H:%M:%S UTC")
                break

        signals.append({
            "id": f"{symbol}_{int(candle_ts)}",
            "symbol": symbol,
            "pattern": pattern,
            "direction": "BUY",
            "entry": round(entry_price, 3 if entry_price < 100 else (2 if entry_price < 10000 else 1)),
            "sl": round(sl, 3 if entry_price < 100 else (2 if entry_price < 10000 else 1)),
            "tp": round(tp, 3 if entry_price < 100 else (2 if entry_price < 10000 else 1)),
            "rr": round(rr, 1),
            "timestamp": candle_time.strftime("%Y-%m-%d %H:%M:%S UTC"),
            "status": outcome,
            "result_r": result_r,
            "exit_price": round(exit_price, 3 if entry_price < 100 else (2 if entry_price < 10000 else 1)) if exit_price else None,
            "exit_time": exit_time,
            "is_live": False,
        })
        last_signal_time = candle_ts

    return signals

async def main():
    s_r25 = await get_signals_for_symbol("R_25")
    s_r75 = await get_signals_for_symbol("R_75")
    all_signals = s_r25 + s_r75
    all_signals.sort(key=lambda x: x["timestamp"], reverse=True)

    print(f"\nFound {len(all_signals)} total signals up to yesterday (2026-09-09)!")
    for s in all_signals[:10]:
        print(f"[{s['timestamp']}] {s['symbol']} {s['direction']} {s['pattern']} -> {s['status']} ({s['result_r']} R)")

    with open("yesterday_signals.json", "w") as f:
        json.dump(all_signals, f, indent=2)
    print("Saved to yesterday_signals.json")

if __name__ == "__main__":
    asyncio.run(main())
