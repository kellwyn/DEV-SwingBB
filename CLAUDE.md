@../Dev-RZY/AGENT.md
@../Dev-RZY/SKILLS.md

<!-- Shared infrastructure imported above. Strategy-specific content below. -->

# CLAUDE.md — DEV-SwingBB

## Strategy

Anthony Crudele Bollinger Trend Fib — environment-first swing strategy for index futures (NQ/ES/RTY).
See [STRATEGY.md](STRATEGY.md) for full rules. See [VERSIONING.md](VERSIONING.md) for branch/commit/PR conventions.

**Core logic:** Classify daily BB environment (consolidation / expansion / mean-reversion) → trade only in that direction → fib levels applied to BB peak range, not price.

---

## Repo Structure

```
DEV-SwingBB/
├── swing-bb-ea/             # MQL5 Expert Advisor (MetaTrader 5)
├── swing-bb-python-bot/     # Python signal generator & auto-execution
├── swing-bb-signal-lab/     # Multi-instrument scanner / research
├── STRATEGY.md              # Full strategy rules (source of truth)
└── VERSIONING.md            # Branch strategy, semver, commit conventions
```

---

## Stack

| Component | Technology |
|-----------|-----------|
| EA | MQL5 (MetaTrader 5) |
| Bot | Python 3.x |
| Signal Lab | Python 3.x |
| Charting | TradingView (reference only — execution in MT5) |
| Data | MT5 tick/bar feed, optional external data source |

---

## Versioning Milestones

| Version | Milestone |
|---------|-----------|
| v1.x.x | MQ5 EA — initial build and backtest |
| v2.x.x | Python bot — active signal detection and execution |
| v3.x.x | Signal Lab — multi-instrument scanner live |
| v4.x.x | Full system integration |

Current version: track via `git tag`.

---

## How to Run

```bash
# Signal Lab
cd swing-bb-signal-lab
pip install -r requirements.txt
python signal_lab.py

# Python bot (once built)
cd swing-bb-python-bot
python bot.py
```

MT5 EA: compile `swing-bb-ea/*.mq5` in MetaEditor, attach to chart in MT5.

---

## Branch Rules (summary — see VERSIONING.md)

| Branch | Purpose |
|--------|---------|
| `main` | Stable releases only |
| `dev` | Active development |
| `feat/<name>` | Feature branches → PR to dev |
| `backtest/<name>` | Backtest experiments — never merge to main |

---

## Key Conventions

- Commit type `backtest(ea):` for any result or parameter update
- PR to `main` requires passing syntax check + manual backtest note in description
- Never commit `.ex5` binaries, `.env`, or `__pycache__/`
- BB settings: Period 20, StdDev **3** — do not change without a full strategy review
- Fib is drawn on the BB peak range, NOT on price swing

---

## EA Execution Findings Log

Append an entry below after each meaningful backtest, forward test, or live run.
Format: date · version · instrument · result · key insight.

---

### Log

```
[2026-04-23] TEMPLATE ENTRY
  Version:    v1.0.0
  Type:       backtest | forward-test | live
  Instrument: NQ / ES / RTY
  Period:     YYYY-MM-DD → YYYY-MM-DD
  Timeframe:  Daily env + 60m execution
  Net P&L:    +$X / -$X
  Win Rate:   XX%
  Avg RR:     1:X
  Max DD:     $X / X%
  Trades:     N
  Environment breakdown:
    Consolidation: X trades, X% win
    Expansion:     X trades, X% win
    Mean-Rev:      X trades, X% win
  Key finding:    [what was learned — parameter sensitivity, edge case, rule gap]
  Action taken:   [what changed in code or strategy rules as a result]
```

---

## Insights & Learnings

<!-- Append dated notes as work progresses -->

- **2026-04-23:** SwingBB is the most mature EA repo — STRATEGY.md and VERSIONING.md exist and are the sources of truth. All rule changes go to STRATEGY.md first, code second.
- **2026-04-23:** BB StdDev=3 is intentional for index futures volatility — do not "fix" it to 2.
- **2026-04-23:** Fib is fibbing volatility (applied to BB peak range), not price. Common mistake to apply it to candle swing highs/lows.

---

## Subagents

| Task | Command |
|---|---|
| Review code | `use the code-reviewer subagent` |
| Security scan | `use the security-reviewer subagent` |
| Bot health | `use the bot-health-check subagent` |
| Deploy EA | `use the ea-deployer subagent` |
| Commit + push | `use the git-push subagent` |
