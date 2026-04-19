"""
Multi-instrument Bollinger Trend Fib scanner.
Scans a watchlist, classifies environment for each symbol,
identifies near-trigger setups. No trade execution.
"""

import os
import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime
from dotenv import load_dotenv

from lab.indicators import bollinger_bands, emas, bb_width_trend

load_dotenv()

BB_PERIOD    = int(os.getenv("BB_PERIOD",    "20"))
BB_DEV       = float(os.getenv("BB_DEVIATION", "3.0"))
ENV_LOOKBACK = int(os.getenv("ENV_LOOKBACK", "5"))

DEFAULT_WATCHLIST = [
    "US500M", "NDAQ", "US30", "GER40", "XAUUSD",
]


def _fetch(symbol: str, bars: int = 100) -> pd.DataFrame | None:
    rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_D1, 0, bars)
    if rates is None or len(rates) == 0:
        return None
    df = pd.DataFrame(rates)
    df["time"] = pd.to_datetime(df["time"], unit="s")
    return df


def scan_symbol(symbol: str) -> dict:
    """
    Return environment classification and key levels for one symbol.
    TODO (v3.x): add mean reversion fib trigger detection.
    """
    df = _fetch(symbol)
    if df is None:
        return {"symbol": symbol, "env": "ERROR", "close": 0}

    df    = bollinger_bands(df, BB_PERIOD, BB_DEV)
    df    = emas(df)
    trend = bb_width_trend(df, ENV_LOOKBACK)

    last      = df.iloc[-1]
    bb_trend  = trend.iloc[-1]
    close     = last["close"]
    edge_pct  = 0.15
    band_rng  = last["bb_upper"] - last["bb_lower"]
    edge      = band_rng * edge_pct

    if bb_trend == "expanding":
        if close >= last["bb_upper"] - edge:
            env = "EXPANSION UP"
        elif close <= last["bb_lower"] + edge:
            env = "EXPANSION DOWN"
        else:
            env = "EXPANSION (mid)"
    elif bb_trend == "contracting":
        env = "CONSOLIDATION"
    else:
        env = "FLAT / TRANSITIONING"

    return {
        "symbol":    symbol,
        "env":       env,
        "close":     round(close, 2),
        "bb_upper":  round(last["bb_upper"], 2),
        "bb_mid":    round(last["bb_mid"],   2),
        "bb_lower":  round(last["bb_lower"], 2),
        "bb_width":  round(last["bb_width"], 2),
        "ema21":     round(last["ema21"],    2),
        "pct_b":     round(last["bb_pct_b"], 3),
        "scanned_at": datetime.now().strftime("%H:%M:%S"),
    }


def run_scan(watchlist: list[str] | None = None) -> list[dict]:
    symbols = watchlist or DEFAULT_WATCHLIST
    results = []
    for sym in symbols:
        if not SymbolSelect(sym, True):
            print(f"  SKIP: {sym} not available")
            continue
        results.append(scan_symbol(sym))
    return results


def SymbolSelect(sym, flag):
    return mt5.symbol_select(sym, flag)
