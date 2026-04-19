"""
SwingBB Signal Lab — entry point
Scans a watchlist for Bollinger Trend Fib environments.
No trade execution — research and signal identification only.
"""

import os
import time
import MetaTrader5 as mt5
from dotenv import load_dotenv

from lab.scanner import run_scan
from lab.report  import print_report, save_csv

load_dotenv()

SCAN_INTERVAL = int(os.getenv("SCAN_INTERVAL", "300"))   # default 5 min
SAVE_CSV      = os.getenv("SAVE_CSV", "false").lower() == "true"

WATCHLIST = [
    "US500M", "NDAQ", "US30", "GER40", "XAUUSD",
]


def main():
    if not mt5.initialize():
        print(f"MT5 initialize() failed: {mt5.last_error()}")
        return

    print("\n  SwingBB Signal Lab — starting scanner...")
    print(f"  Watchlist: {', '.join(WATCHLIST)}")
    print(f"  Interval : {SCAN_INTERVAL}s  |  Ctrl+C to stop\n")

    try:
        while True:
            results = run_scan(WATCHLIST)
            print_report(results)
            if SAVE_CSV:
                save_csv(results)
            time.sleep(SCAN_INTERVAL)
    except KeyboardInterrupt:
        print("\n  Signal Lab stopped.")
    finally:
        mt5.shutdown()


if __name__ == "__main__":
    main()
