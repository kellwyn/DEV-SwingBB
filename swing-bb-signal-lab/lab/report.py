"""
Signal Lab report generator.
Formats scan results to terminal (and optionally CSV).
No trade execution.
"""

import os
import csv
from datetime import datetime


ENV_ICON = {
    "EXPANSION UP":          "▲",
    "EXPANSION DOWN":        "▼",
    "CONSOLIDATION":         "↔",
    "FLAT / TRANSITIONING":  "~",
    "EXPANSION (mid)":       "◈",
    "MEAN REV BEAR":         "↓",
    "MEAN REV BULL":         "↑",
    "ERROR":                 "✗",
}


def print_report(results: list[dict]) -> None:
    W = 90
    print(f"\n  {'─'*W}")
    print(f"  SWING BB SIGNAL LAB  —  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  {'─'*W}")
    print(f"  {'SYM':<10} {'ENV':<26} {'CLOSE':>10}  {'BB_UP':>10}  {'MID':>10}  {'BB_LO':>10}  {'%B':>6}")
    print(f"  {'─'*W}")
    for r in results:
        icon = ENV_ICON.get(r.get("env", ""), " ")
        print(f"  {r['symbol']:<10} {icon} {r.get('env',''):<24} "
              f"{r.get('close',0):>10.2f}  "
              f"{r.get('bb_upper',0):>10.2f}  "
              f"{r.get('bb_mid',0):>10.2f}  "
              f"{r.get('bb_lower',0):>10.2f}  "
              f"{r.get('pct_b',0):>6.3f}")
    print(f"  {'─'*W}")
    print(f"  {len(results)} symbols scanned")


def save_csv(results: list[dict], path: str = "lab_output/scan_results.csv") -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if not results:
        return
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=results[0].keys())
        writer.writeheader()
        writer.writerows(results)
    print(f"  Saved: {path}")
