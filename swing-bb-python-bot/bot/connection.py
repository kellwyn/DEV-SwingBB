import os
import MetaTrader5 as mt5
from dotenv import load_dotenv

load_dotenv()


def connect():
    if not mt5.initialize():
        raise RuntimeError(f"MT5 initialize() failed: {mt5.last_error()}")

    login    = os.getenv("MT5_LOGIN")
    password = os.getenv("MT5_PASSWORD")
    server   = os.getenv("MT5_SERVER")

    if login and password and server:
        if not mt5.login(int(login), password=password, server=server):
            mt5.shutdown()
            raise RuntimeError(f"MT5 login failed: {mt5.last_error()}")

    info = mt5.account_info()
    if info is None:
        mt5.shutdown()
        raise RuntimeError("No account info — ensure MT5 is open and logged in.")

    print(f"Connected | Account: {info.login} | Broker: {info.company} | Balance: {info.balance} {info.currency}")
    return info


def disconnect():
    mt5.shutdown()
    print("Disconnected from MT5.")
