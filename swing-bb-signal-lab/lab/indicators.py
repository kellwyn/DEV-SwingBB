"""
Indicator calculations for the Signal Lab.
No trade execution — research and scanning only.
"""

import pandas as pd
import numpy as np


def bollinger_bands(df: pd.DataFrame, period: int = 20, dev: float = 3.0) -> pd.DataFrame:
    df = df.copy()
    df["bb_mid"]   = df["close"].rolling(period).mean()
    df["bb_std"]   = df["close"].rolling(period).std()
    df["bb_upper"] = df["bb_mid"] + dev * df["bb_std"]
    df["bb_lower"] = df["bb_mid"] - dev * df["bb_std"]
    df["bb_width"] = df["bb_upper"] - df["bb_lower"]
    df["bb_pct_b"] = (df["close"] - df["bb_lower"]) / (df["bb_upper"] - df["bb_lower"])
    return df


def emas(df: pd.DataFrame, periods: list[int] = [8, 21, 34]) -> pd.DataFrame:
    df = df.copy()
    for p in periods:
        df[f"ema{p}"] = df["close"].ewm(span=p, adjust=False).mean()
    return df


def bb_width_trend(df: pd.DataFrame, lookback: int = 5) -> pd.Series:
    """Returns 'expanding', 'contracting', or 'flat' for each bar."""
    def classify(row_idx):
        if row_idx < lookback:
            return "flat"
        current  = df["bb_width"].iloc[row_idx]
        oldest   = df["bb_width"].iloc[row_idx - lookback]
        prev     = df["bb_width"].iloc[row_idx - 1]
        if current > prev and current > oldest:
            return "expanding"
        if current < prev and current < oldest:
            return "contracting"
        return "flat"
    return pd.Series([classify(i) for i in range(len(df))], index=df.index)


def fib_levels(peak: float, trough: float, levels: list[float] = [0.30, 0.50, 0.70]) -> dict:
    """Calculate fib retracement levels from a peak-to-trough range."""
    rng = abs(peak - trough)
    return {str(int(l * 100)): peak - rng * l if peak > trough else peak + rng * l
            for l in levels}
