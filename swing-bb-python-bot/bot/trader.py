"""
Trade execution with manual confirmation — scaffold.
Full implementation: v2.x milestone.
"""

import os
import MetaTrader5 as mt5
from dotenv import load_dotenv
from bot.signals import Signal, Direction

load_dotenv()

MANUAL_CONFIRM = os.getenv("MANUAL_CONFIRM", "true").lower() == "true"
MAX_RISK_PCT   = float(os.getenv("MAX_RISK_PCT", "1.0"))
SL_POINTS      = float(os.getenv("STOP_LOSS_POINTS", "25"))


def execute(signal: Signal) -> bool:
    """
    Display signal context, optionally confirm, execute trade.
    TODO (v2.x): implement full Kelly sizing + confirmation panel.
    """
    if signal.direction == Direction.NONE:
        print(f"  [ALERT] {signal.environment.value} — no trade direction.")
        return False

    print(f"\n  Signal: {signal.environment.value}  |  {signal.direction.value}  {signal.symbol}")
    print(f"  Entry: {signal.entry_price:.2f}  SL: {signal.stop_loss:.2f}  TP: {signal.take_profit:.2f}")

    if MANUAL_CONFIRM:
        choice = input("  Confirm trade? [y/n]: ").strip().lower()
        if choice not in ("y", "yes"):
            print("  Trade skipped.")
            return False

    # TODO: build and send MT5 order_send request
    print("  [SCAFFOLD] Order execution not yet implemented (v2.x).")
    return False
