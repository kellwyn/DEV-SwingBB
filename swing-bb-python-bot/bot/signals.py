from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime


class MarketEnv(Enum):
    UNKNOWN        = "UNKNOWN"
    CONSOLIDATION  = "CONSOLIDATION"       # Bands contracting — two-way tape
    EXPANSION_UP   = "EXPANSION UP"        # Bands expanding upward — long only
    EXPANSION_DN   = "EXPANSION DOWN"      # Bands expanding downward — short only
    MEAN_REV_BEAR  = "MEAN REVERSION BEAR" # Contracting after expansion up, below 30% fib
    MEAN_REV_BULL  = "MEAN REVERSION BULL" # Contracting after expansion down, above 70% fib


class Direction(Enum):
    LONG  = "BUY"
    SHORT = "SELL"
    NONE  = "NONE"


@dataclass
class BBLevels:
    upper:  float = 0.0
    middle: float = 0.0
    lower:  float = 0.0
    width:  float = 0.0


@dataclass
class FibLevels:
    high:    float = 0.0
    low:     float = 0.0
    level30: float = 0.0   # Trigger
    level50: float = 0.0   # Target
    level70: float = 0.0   # Extended


@dataclass
class Signal:
    environment:  MarketEnv
    direction:    Direction
    symbol:       str
    entry_price:  float

    bb:           BBLevels  = field(default_factory=BBLevels)
    fib:          FibLevels = field(default_factory=FibLevels)

    ema8:         float = 0.0
    ema21:        float = 0.0
    ema34:        float = 0.0

    stop_loss:    float = 0.0
    take_profit:  float = 0.0
    probability:  float = 0.0
    rr_ratio:     float = 0.0

    reason:       list[str] = field(default_factory=list)
    timestamp:    datetime  = field(default_factory=datetime.now)
