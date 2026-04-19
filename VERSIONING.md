# Git Versioning Rules — DEV-SwingBB

## Branch Strategy
| Branch | Purpose |
|---|---|
| `main` | Stable, tested releases only |
| `dev` | Active development integration |
| `feat/<name>` | Feature branches — merge to dev via PR |
| `fix/<name>` | Bug fix branches |
| `backtest/<name>` | Backtesting experiments — never merge to main |

## Semantic Versioning
Tags follow `vMAJOR.MINOR.PATCH`:

| Change | Bump |
|---|---|
| Breaking strategy rule change or full environment rebuild | MAJOR |
| New signal type, new environment rule, new module feature | MINOR |
| Bug fix, parameter tweak, performance improvement | PATCH |

### Version Milestones
| Version | Milestone |
|---|---|
| v1.x.x | MQ5 EA — initial build and backtest |
| v2.x.x | Python bot — active signal detection and execution |
| v3.x.x | Signal Lab — multi-instrument scanner live |
| v4.x.x | Full system integration (bot + lab + EA parity) |

## Commit Message Convention
```
<type>(<scope>): <short description>

[optional body — what changed and why]
[optional refs — issue/backtest numbers]
```

### Types
| Type | When to use |
|---|---|
| `feat` | New feature or strategy rule |
| `fix` | Bug or logic correction |
| `refactor` | Code restructure, no behaviour change |
| `backtest` | Backtest result or parameter update |
| `docs` | Strategy docs, README, comments |
| `chore` | Build, deps, repo config |

### Scopes
`ea` · `bot` · `lab` · `signals` · `risk` · `env` · `fib` · `docs`

### Examples
```
feat(ea): add consolidation two-way tape edge entries
fix(ea): correct bearish mean reversion 30% fib trigger
backtest(ea): v1.1.0 results on US500M 2022-2024
feat(bot): scaffold BB environment detector
docs(strategy): add mean reversion fib rules
chore: add .gitignore for Python pycache
```

## Pull Request Rules
- PRs to `main` require passing syntax check + manual backtest note
- PR description must state: environment tested, date range, key metrics
- No direct pushes to `main`

## What NOT to Commit
- `.env` files (credentials)
- `__pycache__/` and `*.pyc`
- Compiled MQ5 binaries (`*.ex5`)
- PDF playbooks
- `.venv/` virtual environments
