"""
Bollinger Trend Fib — Strategy Engine (scaffold)
Full implementation: v2.x milestone
"""

import os
import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from dotenv import load_dotenv
from datetime import datetime

from bot.signals import Signal, MarketEnv, Direction, BBLevels, FibLevels

load_dotenv()

SYMBOL      = os.getenv("TRADE_SYMBOL", "US500M")
BB_PERIOD   = int(os.getenv("BB_PERIOD", "20"))
BB_DEV      = float(os.getenv("BB_DEVIATION", "3.0"))
FIB_LOOKBACK = 50


def _daily_rates(n: int = 100) -> pd.DataFrame:
    rates = mt5.copy_rates_from_pos(SYMBOL, mt5.TIMEFRAME_D1, 0, n)
    if rates is None or len(rates) == 0:
        raise RuntimeError(f"Cannot fetch daily data for {SYMBOL}")
    df = pd.DataFrame(rates)
    df["time"] = pd.to_datetime(df["time"], unit="s")
    return df


def _bollinger(df: pd.DataFrame) -> pd.DataFrame:
    df["bb_mid"]   = df["close"].rolling(BB_PERIOD).mean()
    df["bb_std"]   = df["close"].rolling(BB_PERIOD).std()
    df["bb_upper"] = df["bb_mid"] + BB_DEV * df["bb_std"]
    df["bb_lower"] = df["bb_mid"] - BB_DEV * df["bb_std"]
    df["bb_width"] = df["bb_upper"] - df["bb_lower"]
    return df


def _emas(df: pd.DataFrame) -> pd.DataFrame:
    for p in [8, 21, 34]:
        df[f"ema{p}"] = df["close"].ewm(span=p, adjust=False).mean()
    return df


def classify_environment(df: pd.DataFrame) -> MarketEnv:
    """
    Classify the current daily BB environment.
    TODO (v2.x): implement full environment classification matching MQ5 EA logic.
    """
    # Scaffold — returns UNKNOWN until fully implemented
    return MarketEnv.UNKNOWN


def calc_fib_levels(df: pd.DataFrame, env: MarketEnv) -> FibLevels:
    """
    Calculate mean-reversion fib levels on BB peak-to-middle range.
    TODO (v2.x): implement Beacon-equivalent fib calculation.
    """
    return FibLevels()


def get_signal() -> Signal | None:
    """
    Main entry point: fetch data, classify environment, return Signal or None.
    TODO (v2.x): wire up full signal generation.
    """
    try:
        df  = _daily_rates()
        df  = _bollinger(df)
        df  = _emas(df)
        env = classify_environment(df)

        if env == MarketEnv.UNKNOWN:
            return None

        # TODO: build full Signal object for each environment
        return None

    except Exception as e:
        print(f"  Strategy error: {e}")
        return None


def print_dashboard(df: pd.DataFrame) -> None:
    """Print a quick market state overview to terminal."""
    if df.empty or "bb_upper" not in df.columns:
        return
    last = df.iloc[-1]
    print(f"\n  {'─'*55}")
    print(f"  SwingBB Scanner  —  {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"  {'─'*55}")
    print(f"  {SYMBOL:<12}  Close: {last['close']:>10.2f}")
    print(f"  BB Upper:  {last['bb_upper']:>10.2f}   BB Mid: {last['bb_mid']:>10.2f}   BB Lower: {last['bb_lower']:>10.2f}")
    print(f"  EMA8:      {last['ema8']:>10.2f}   EMA21:  {last['ema21']:>10.2f}   EMA34:    {last['ema34']:>10.2f}")
    print(f"  BB Width:  {last['bb_width']:>10.2f}")
    print(f"  {'─'*55}")
