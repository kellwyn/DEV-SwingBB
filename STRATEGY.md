# Anthony Crudele — Bollinger Trend Fib Strategy

## Overview
Environment-first swing trading strategy for index futures (S&P / Nasdaq / Russell).
Before any trade is considered, the market environment is classified on the **daily chart**
using Bollinger Bands (20, 3). Only once the environment is clear does execution begin.

---

## Instruments & Timeframes
| Use | Timeframe |
|---|---|
| Environment classification | Daily |
| Entry refinement | 60-min / 30-min / 3-min |
| Typical hold | 1–5 trading days |

---

## Indicator Settings
| Indicator | Setting | Purpose |
|---|---|---|
| Bollinger Bands | Period 20, StdDev **3** | Environment classification |
| EMA 8 / 21 / 34 | Daily + execution TF | Exit context, not entry signals |
| RSI (optional) | Default | Confirm overbought/oversold in mean reversion only |
| Anchored VWAP | Situational | Extreme volatility exit management |

> The 3 standard-deviation setting is intentional — gives enough room for index
> volatility and avoids constant overbought/oversold noise.

---

## Three Market Environments

### 1. Consolidation (Two-Way Tape)
**What it looks like:** Bands contracting, price rangebound, often after a meaningful move.

**Rules:**
- Trade BOTH directions (long near lower band, short near upper band)
- Stay OUT of the middle
- Expect stop-runs above highs / below lows that snap back into range
- Drop to 60-min / 30-min for execution
- Use smaller size — this environment chops multi-day swings

**Risk note:** Most likely environment to produce losses for trend-followers.

---

### 2. Trend / Expansion (One-Directional Only)
**What it looks like:** Bands expanding outward, price touching the upper or lower band.

**Bullish Expansion:**
- Bands expanding upward + price breaks out above range → **LONG ONLY**
- No shorting rallies, no fading the trend

**Bearish Expansion:**
- Bands expanding downward + breakdown → **SHORT ONLY**
- No buying dips, no counter-trend longs

**Targets (in order of priority):**
1. Prior Bollinger Band peak ("unfinished business" concept) — when bands peaked
   previously and price now trends again, that prior peak becomes the objective
2. Weekly highs/lows and major higher-timeframe reference levels

**Stop placement:**
- Longs: below key swing low or below 21 EMA
- Shorts: above key swing high or above 21 EMA
- If stop is unrealistically wide on futures → use options (defined risk by premium)

---

### 3. Mean Reversion — Pullback Phase (Defined Trigger + Target)
**What it looks like:** After expansion, bands begin contracting — the "you missed the
top/bottom" phase. The strategy does NOT try to nail tops or bottoms.

**Fib Framework (applied to Bollinger Band peak, not price):**
> "Fibbing volatility, not price" — the fib is drawn on the BB peak-to-middle range
> once the expansion peak is confirmed.

| Level | Role |
|---|---|
| 30% | Entry trigger — daily close through 30% line |
| 50% | Main target — mean reversion objective complete |
| 70% | Extended target (rarely pursued) |

**Bearish mean reversion:**
- Daily close below 30% fib line → short (or buy puts)
- Target: 50% fib level
- Exit: when 50% hit — strategy is done here
- Stop: above the last expansion high

**Bullish mean reversion:**
- Daily close above 70% fib line (i.e., 30% off the low) → long
- Target: 50% fib level
- Stop: below the last expansion low

**After 50% is hit → "hands in pocket" zone:**
- Price may chop and consolidate
- Or may transition to a new expansion phase
- Strategy waits for environment to become clear again

**Sizing rule:** Smaller position size when trading against the primary trend.

---

## Daily Process (Non-Negotiable)
1. Open the daily chart
2. Classify environment using Bollinger Bands
3. Set posture (two-way / one-direction / mean-reversion)
4. Drop to lower timeframe only to improve execution quality

---

## Risk Management
- Risk is managed in **dollars per trade**, not fixed contracts
- Large stop → use options (risk capped by premium)
- Typical options selection: 3–5 DTE puts/calls on index futures
- Scale out into targets — partial exits as price moves through levels

---

## Trade Management Tools
- **8/21/34 EMAs:** Exit context — is price holding above/below key averages?
- **Anchored VWAP:** Anchor to the candle where tape turned (key high/low).
  Use VWAP + deviation bands as trim/exit guides in volatile conditions.
