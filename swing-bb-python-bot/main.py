"""
SwingBB Python Bot — entry point (scaffold)
Full bot implementation: v2.x milestone
"""

import os
import time
from dotenv import load_dotenv

from bot.connection import connect, disconnect
from bot.strategy   import get_signal, print_dashboard, _daily_rates, _bollinger, _emas
from bot.trader     import execute

load_dotenv()

SCAN_INTERVAL = int(os.getenv("SCAN_INTERVAL", "60"))


def run():
    print("\n  SwingBB Bot — starting scanner (scaffold mode)...")
    print(f"  Scan interval: {SCAN_INTERVAL}s  |  Ctrl+C to stop\n")

    while True:
        try:
            df     = _daily_rates()
            df     = _bollinger(df)
            df     = _emas(df)
            print_dashboard(df)

            signal = get_signal()
            if signal:
                execute(signal)
            else:
                print("  No setup detected — monitoring...")

            time.sleep(SCAN_INTERVAL)

        except KeyboardInterrupt:
            print("\n  Stopped.")
            break
        except Exception as e:
            print(f"  ERROR: {e}")
            time.sleep(SCAN_INTERVAL)


def main():
    try:
        connect()
        run()
    finally:
        disconnect()


if __name__ == "__main__":
    main()
