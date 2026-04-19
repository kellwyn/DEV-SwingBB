//+------------------------------------------------------------------+
//|  SwingBBEA.mq5                                                   |
//|  Anthony Crudele — Bollinger Trend Fib Strategy                  |
//|  v1.0.0                                                          |
//|                                                                  |
//|  Backtest symbol : US500M                                        |
//|                                                                  |
//|  Three environments (daily Bollinger Bands 20/3):                |
//|    1. CONSOLIDATION  — two-way tape, trade band edges            |
//|    2. EXPANSION      — one direction only, trend continuation    |
//|    3. MEAN REVERSION — fib-on-BB-peak trigger, 50% target       |
//|                                                                  |
//|  Sizing  : Kelly Criterion (half-kelly, capped at MaxRiskPct)    |
//|  Confirm : optional MessageBox for live trading                  |
//+------------------------------------------------------------------+
#property copyright "Anthony Crudele Bollinger Trend Fib EA"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//── Inputs ────────────────────────────────────────────────────────────────────
input group "=== Symbols ==="
input string   TradeSymbol      = "US500M";     // Main instrument

input group "=== Bollinger Bands (Daily) ==="
input int      BB_Period        = 20;           // BB period
input double   BB_Deviation     = 3.0;          // BB standard deviations (3 = intentional)

input group "=== Moving Averages ==="
input int      MA_Fast          = 8;            // Fast EMA period
input int      MA_Mid           = 21;           // Mid EMA period
input int      MA_Slow          = 34;           // Slow EMA period

input group "=== Environment Detection ==="
input int      EnvLookback      = 5;            // Bars to confirm expansion/contraction
input double   BandEdgePct      = 0.15;         // % of band width to define "near edge"
input int      FibLookback      = 50;           // Bars to look back for BB peak

input group "=== Mean Reversion Fib ==="
input double   FibTrigger       = 0.30;         // Fib trigger level (30%)
input double   FibTarget        = 0.50;         // Fib target level  (50%)
input double   FibExtended      = 0.70;         // Extended fib level (70%)

input group "=== Execution ==="
input ENUM_TIMEFRAMES Timeframe = PERIOD_M30;   // Execution timeframe
input double   StopLossPts      = 25.0;         // Stop loss in points
input double   MaxRiskPct       = 1.0;          // Max risk % per trade (Kelly cap)
input int      MagicNumber      = 303000;       // EA magic number
input bool     ManualConfirm    = false;        // Manual confirm dialog (disable for backtest)
input bool     AllowConsolidation = true;       // Trade consolidation environment
input bool     AllowExpansion   = true;         // Trade expansion environment
input bool     AllowMeanRev     = true;         // Trade mean reversion environment

//── Market Environment Enum ───────────────────────────────────────────────────
enum ENUM_ENV {
   ENV_UNKNOWN        = 0,
   ENV_CONSOLIDATION  = 1,   // Bands contracting, rangebound
   ENV_EXPANSION_UP   = 2,   // Bands expanding upward — long only
   ENV_EXPANSION_DN   = 3,   // Bands expanding downward — short only
   ENV_MEAN_REV_BEAR  = 4,   // After expansion up, bands contracting, below 30% fib
   ENV_MEAN_REV_BULL  = 5,   // After expansion down, bands contracting, above 70% fib
};

string EnvName(ENUM_ENV e) {
   switch(e) {
      case ENV_CONSOLIDATION : return "CONSOLIDATION";
      case ENV_EXPANSION_UP  : return "EXPANSION UP (Long Only)";
      case ENV_EXPANSION_DN  : return "EXPANSION DOWN (Short Only)";
      case ENV_MEAN_REV_BEAR : return "MEAN REVERSION — Bearish";
      case ENV_MEAN_REV_BULL : return "MEAN REVERSION — Bullish";
      default:                 return "UNKNOWN";
   }
}

//── Globals ───────────────────────────────────────────────────────────────────
CTrade         Trade;
datetime       g_lastBarTime = 0;
ENUM_ENV       g_lastEnv     = ENV_UNKNOWN;
string         g_lastSignal  = "";

//+------------------------------------------------------------------+
//| Expert init                                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   Trade.SetExpertMagicNumber(MagicNumber);
   Trade.SetDeviationInPoints(20);
   if(!SymbolSelect(TradeSymbol, true))
      PrintFormat("WARNING: %s not in Market Watch — add it and restart.", TradeSymbol);
   Print("SwingBBEA v1.0.0 initialised on ", TradeSymbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Get daily Bollinger Band values for a given bar shift            |
//+------------------------------------------------------------------+
bool GetDailyBB(int shift, double &upper, double &middle, double &lower)
{
   int handle = iBands(TradeSymbol, PERIOD_D1, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return false;
   double u[], m[], l[];
   if(CopyBuffer(handle, 1, shift, 1, u) < 1) return false;
   if(CopyBuffer(handle, 0, shift, 1, m) < 1) return false;
   if(CopyBuffer(handle, 2, shift, 1, l) < 1) return false;
   upper  = u[0];
   middle = m[0];
   lower  = l[0];
   IndicatorRelease(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Get daily EMA value                                              |
//+------------------------------------------------------------------+
double GetDailyEMA(int period, int shift)
{
   int handle = iMA(TradeSymbol, PERIOD_D1, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return 0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1) { IndicatorRelease(handle); return 0; }
   IndicatorRelease(handle);
   return buf[0];
}

//+------------------------------------------------------------------+
//| Classify daily Bollinger Band environment                        |
//|                                                                  |
//| Returns current environment based on:                            |
//|  - BB width trend (contracting vs expanding)                     |
//|  - Price position relative to bands                              |
//|  - Recent expansion peak (for mean reversion)                    |
//+------------------------------------------------------------------+
ENUM_ENV ClassifyEnvironment(
   double &fibHigh, double &fibLow,
   double &level30, double &level50, double &level70
)
{
   // Collect BB width over EnvLookback+1 bars
   double widths[];
   ArrayResize(widths, EnvLookback + 1);
   for(int i = 0; i <= EnvLookback; i++)
   {
      double u, m, l;
      if(!GetDailyBB(i, u, m, l)) return ENV_UNKNOWN;
      widths[i] = u - l;
   }

   double currentWidth  = widths[0];
   double prevWidth     = widths[1];
   double oldestWidth   = widths[EnvLookback];

   bool expanding    = currentWidth > prevWidth && currentWidth > oldestWidth;
   bool contracting  = currentWidth < prevWidth && currentWidth < oldestWidth;

   // Current bar values
   double upper, middle, lower;
   if(!GetDailyBB(0, upper, middle, lower)) return ENV_UNKNOWN;

   double close = iClose(TradeSymbol, PERIOD_D1, 0);
   double bandRange = upper - lower;
   double edgeBand  = bandRange * BandEdgePct;

   double ema21 = GetDailyEMA(MA_Mid, 0);

   // ── EXPANSION UP: bands expanding, price above middle ─────────────
   if(expanding && close > middle && close >= upper - edgeBand)
      return ENV_EXPANSION_UP;

   // ── EXPANSION DOWN: bands expanding, price below middle ───────────
   if(expanding && close < middle && close <= lower + edgeBand)
      return ENV_EXPANSION_DN;

   // ── MEAN REVERSION after expansion ────────────────────────────────
   // Find the peak BB bar in the lookback window
   if(contracting)
   {
      double peakUpperBand = 0, lowestLowerBand = 1e10;
      int    peakBar = 1;
      int    troughBar = 1;

      int bbHandle = iBands(TradeSymbol, PERIOD_D1, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
      if(bbHandle != INVALID_HANDLE)
      {
         double uBuf[], lBuf[];
         int n = FibLookback;
         if(CopyBuffer(bbHandle, 1, 1, n, uBuf) == n &&
            CopyBuffer(bbHandle, 2, 1, n, lBuf) == n)
         {
            for(int i = 0; i < n; i++)
            {
               if(uBuf[i] > peakUpperBand) { peakUpperBand = uBuf[i]; peakBar = i + 1; }
               if(lBuf[i] < lowestLowerBand) { lowestLowerBand = lBuf[i]; troughBar = i + 1; }
            }
         }
         IndicatorRelease(bbHandle);
      }

      // Bearish mean reversion: was there a significant expansion up?
      // Peak upper band is well above current middle
      if(peakUpperBand > middle * 1.005)
      {
         // Fib on BB peak upper to current middle (volatility fib)
         fibHigh  = peakUpperBand;
         fibLow   = middle;
         double range = fibHigh - fibLow;
         level30  = fibHigh - range * FibTrigger;   // 30% — trigger line
         level50  = fibHigh - range * FibTarget;    // 50% — main target
         level70  = fibHigh - range * FibExtended;  // 70% — extended

         // Trigger: daily close below 30% line
         if(close <= level30)
            return ENV_MEAN_REV_BEAR;
      }

      // Bullish mean reversion: was there a significant expansion down?
      if(lowestLowerBand < middle * 0.995)
      {
         fibHigh  = middle;
         fibLow   = lowestLowerBand;
         double range = fibHigh - fibLow;
         level30  = fibLow  + range * FibTrigger;   // 30% off low
         level50  = fibLow  + range * FibTarget;    // 50% — main target
         level70  = fibLow  + range * FibExtended;  // 70%

         // Trigger: daily close above 70% line (i.e., 30% off the low)
         if(close >= level70)
            return ENV_MEAN_REV_BULL;
      }

      // Contracting but no clear mean-rev trigger → consolidation
      return ENV_CONSOLIDATION;
   }

   // ── CONSOLIDATION: anything else with contracting/flat bands ──────
   if(contracting || (!expanding && !contracting))
      return ENV_CONSOLIDATION;

   return ENV_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Kelly Criterion — half-kelly fraction                            |
//+------------------------------------------------------------------+
double HalfKelly(double prob, double rr)
{
   if(rr <= 0 || prob <= 0 || prob >= 1) return 0;
   double full = (rr * prob - (1.0 - prob)) / rr;
   return MathMax(0, full / 2.0);
}

double CalcLot(double slPts, double prob, double rr)
{
   double hk        = HalfKelly(prob, rr);
   if(hk <= 0) return 0;
   double effRisk   = MathMin(hk, MaxRiskPct / 100.0);
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt   = balance * effRisk;
   double tickVal   = SymbolInfoDouble(TradeSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz    = SymbolInfoDouble(TradeSymbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz == 0 || tickVal == 0) return 0;
   double riskPerLot = (slPts / tickSz) * tickVal;
   if(riskPerLot == 0) return 0;
   double lot  = riskAmt / riskPerLot;
   double minL = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   return MathMax(minL, MathMin(maxL, lot));
}

//+------------------------------------------------------------------+
//| Single-trade Sharpe estimate                                     |
//+------------------------------------------------------------------+
double SingleSharpe(double prob, double reward, double risk)
{
   if(prob <= 0 || prob >= 1 || risk <= 0) return 0;
   double eR   = prob * reward - (1 - prob) * risk;
   double stdR = MathSqrt(prob * (1 - prob)) * (reward + risk);
   return stdR > 0 ? eR / stdR : 0;
}

//+------------------------------------------------------------------+
//| Log full signal card to Experts journal                          |
//+------------------------------------------------------------------+
void LogSignalCard(
   ENUM_ENV env,     string direction,
   double entry,     double sl,         double tp,
   double lot,       double prob,        double rr,
   double level30,   double level50,     double level70,
   double bbUpper,   double bbMiddle,    double bbLower,
   double ema8,      double ema21,       double ema34
)
{
   double tickVal   = SymbolInfoDouble(TradeSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz    = SymbolInfoDouble(TradeSymbol, SYMBOL_TRADE_TICK_SIZE);
   double riskAmt   = (tickSz > 0) ? lot * (StopLossPts / tickSz) * tickVal : 0;
   double rewardAmt = riskAmt * rr;
   double sharpe    = SingleSharpe(prob, rewardAmt, riskAmt);

   PrintFormat("╔══════════════════════════════════════════════════════╗");
   PrintFormat("  SwingBB SIGNAL  |  %s  |  %s", EnvName(env), direction);
   PrintFormat("──────────────────────────────────────────────────────");
   PrintFormat("  ENVIRONMENT CONTEXT");
   PrintFormat("  BB Upper   %.2f  |  Middle %.2f  |  Lower %.2f", bbUpper, bbMiddle, bbLower);
   PrintFormat("  EMA8  %.2f  |  EMA21 %.2f  |  EMA34 %.2f", ema8, ema21, ema34);
   if(env == ENV_MEAN_REV_BEAR || env == ENV_MEAN_REV_BULL) {
      PrintFormat("──────────────────────────────────────────────────────");
      PrintFormat("  FIB LEVELS (applied to BB peak, not price)");
      PrintFormat("  30%% Trigger  %.2f  |  50%% Target  %.2f  |  70%% Ext  %.2f",
                  level30, level50, level70);
   }
   PrintFormat("──────────────────────────────────────────────────────");
   PrintFormat("  TRADE PARAMETERS");
   PrintFormat("  Direction    %s", direction);
   PrintFormat("  Entry        %.2f", entry);
   PrintFormat("  Stop Loss    %.2f  (%g pts)", sl, StopLossPts);
   PrintFormat("  Take Profit  %.2f  (50%% fib = %.2f)", tp, level50);
   PrintFormat("──────────────────────────────────────────────────────");
   PrintFormat("  KELLY POSITION SIZING");
   PrintFormat("  Win Prob     %.0f%%  |  R:R 1:%.2f", prob * 100, rr);
   PrintFormat("  Lot          %.2f", lot);
   PrintFormat("  Risk $       $%.2f  |  Reward $  $%.2f", riskAmt, rewardAmt);
   PrintFormat("  Sharpe       %.3f  (single-trade estimate)", sharpe);
   PrintFormat("  Balance      $%.2f", AccountInfoDouble(ACCOUNT_BALANCE));
   PrintFormat("╚══════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| Check if already in a position for this EA                       |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetSymbol(i) == TradeSymbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   return false;
}

//+------------------------------------------------------------------+
//| Place trade with optional confirm dialog                         |
//+------------------------------------------------------------------+
bool PlaceTrade(ENUM_ORDER_TYPE type, double lot, double sl, double tp, string comment)
{
   if(lot <= 0) { Print("Kelly returned 0 lot — negative EV or sizing error."); return false; }

   if(ManualConfirm && !MQLInfoInteger(MQL_TESTER))
   {
      string msg = StringFormat("Confirm %s  %s\nLot:%.2f  SL:%.2f  TP:%.2f\n\nProceed?",
                                (type==ORDER_TYPE_BUY?"BUY":"SELL"), TradeSymbol, lot, sl, tp);
      if(MessageBox(msg, "SwingBB EA", MB_YESNO|MB_ICONQUESTION) != IDYES)
      { Print("Trade declined."); return false; }
   }

   bool ok = (type == ORDER_TYPE_BUY)
             ? Trade.Buy (lot, TradeSymbol, 0, sl, tp, comment)
             : Trade.Sell(lot, TradeSymbol, 0, sl, tp, comment);

   if(!ok) PrintFormat("Order failed: %d  %s", Trade.ResultRetcode(),
                                               Trade.ResultRetcodeDescription());
   return ok;
}

//+------------------------------------------------------------------+
//| Main tick logic                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   // Fire once per closed bar on the execution timeframe
   datetime barTime = iTime(TradeSymbol, Timeframe, 0);
   if(barTime == g_lastBarTime) return;
   g_lastBarTime = barTime;

   if(HasOpenPosition()) return;

   // ── Daily BB values ────────────────────────────────────────────────
   double upper, middle, lower;
   if(!GetDailyBB(0, upper, middle, lower)) return;

   double close = iClose(TradeSymbol, PERIOD_D1, 0);
   double pt    = SymbolInfoDouble(TradeSymbol, SYMBOL_POINT);

   double ema8  = GetDailyEMA(MA_Fast, 0);
   double ema21 = GetDailyEMA(MA_Mid,  0);
   double ema34 = GetDailyEMA(MA_Slow, 0);

   // ── Classify environment ───────────────────────────────────────────
   double fibHigh=0, fibLow=0, level30=0, level50=0, level70=0;
   ENUM_ENV env = ClassifyEnvironment(fibHigh, fibLow, level30, level50, level70);

   if(env == ENV_UNKNOWN) return;

   // Log environment change
   if(env != g_lastEnv)
   {
      PrintFormat(">>> Environment changed: %s → %s  (close=%.2f)",
                  EnvName(g_lastEnv), EnvName(env), close);
      g_lastEnv = env;
   }

   // ── Deduplicate signals within same bar ───────────────────────────
   string signalKey = EnvName(env) + TimeToString(barTime, TIME_DATE|TIME_MINUTES);
   if(signalKey == g_lastSignal) return;

   double slPrice, tpPrice, lot;
   string direction, comment;

   // ══════════════════════════════════════════════════════════════════
   // ENVIRONMENT 1: CONSOLIDATION — trade band edges both ways
   // ══════════════════════════════════════════════════════════════════
   if(env == ENV_CONSOLIDATION && AllowConsolidation)
   {
      double bandRange = upper - lower;
      double edge      = bandRange * BandEdgePct;
      double prob      = 0.55;
      double rr        = 1.5;

      // Near upper band → short (expect reversion into range)
      if(close >= upper - edge && close < upper + pt)
      {
         slPrice   = upper + StopLossPts * pt;
         tpPrice   = middle;                          // target: band middle
         lot       = CalcLot(StopLossPts, prob, rr);
         direction = "SHORT (Consolidation upper edge)";
         comment   = "SwingBB|CONS|SHORT";
         g_lastSignal = signalKey;

         LogSignalCard(env, direction, close, slPrice, tpPrice,
                       lot, prob, rr, level30, level50, level70,
                       upper, middle, lower, ema8, ema21, ema34);
         PlaceTrade(ORDER_TYPE_SELL, lot, slPrice, tpPrice, comment);
         return;
      }

      // Near lower band → long (expect reversion into range)
      if(close <= lower + edge && close > lower - pt)
      {
         slPrice   = lower - StopLossPts * pt;
         tpPrice   = middle;
         lot       = CalcLot(StopLossPts, prob, rr);
         direction = "LONG (Consolidation lower edge)";
         comment   = "SwingBB|CONS|LONG";
         g_lastSignal = signalKey;

         LogSignalCard(env, direction, close, slPrice, tpPrice,
                       lot, prob, rr, level30, level50, level70,
                       upper, middle, lower, ema8, ema21, ema34);
         PlaceTrade(ORDER_TYPE_BUY, lot, slPrice, tpPrice, comment);
         return;
      }
   }

   // ══════════════════════════════════════════════════════════════════
   // ENVIRONMENT 2a: EXPANSION UP — LONG ONLY
   // ══════════════════════════════════════════════════════════════════
   if(env == ENV_EXPANSION_UP && AllowExpansion)
   {
      // Entry: close above EMA21 and near/touching upper band
      if(close > ema21)
      {
         double prob = 0.62;
         double rr   = 2.0;

         // Target: look for prior BB peak ("unfinished business")
         // Use the highest upper band in the lookback as reference target
         double priorPeakTarget = 0;
         int bbH = iBands(TradeSymbol, PERIOD_D1, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
         if(bbH != INVALID_HANDLE) {
            double uBuf[];
            if(CopyBuffer(bbH, 1, 1, FibLookback, uBuf) == FibLookback)
               for(int i = 1; i < FibLookback; i++)
                  priorPeakTarget = MathMax(priorPeakTarget, uBuf[i]);
            IndicatorRelease(bbH);
         }
         if(priorPeakTarget <= close) priorPeakTarget = close + StopLossPts * rr * pt;

         slPrice   = MathMin(ema21, close) - StopLossPts * pt;
         tpPrice   = priorPeakTarget;
         lot       = CalcLot(StopLossPts, prob, rr);
         direction = "LONG (Expansion Up — trend continuation)";
         comment   = "SwingBB|EXP_UP|LONG";
         g_lastSignal = signalKey;

         LogSignalCard(env, direction, close, slPrice, tpPrice,
                       lot, prob, rr, 0, tpPrice, 0,
                       upper, middle, lower, ema8, ema21, ema34);
         PlaceTrade(ORDER_TYPE_BUY, lot, slPrice, tpPrice, comment);
         return;
      }
   }

   // ══════════════════════════════════════════════════════════════════
   // ENVIRONMENT 2b: EXPANSION DOWN — SHORT ONLY
   // ══════════════════════════════════════════════════════════════════
   if(env == ENV_EXPANSION_DN && AllowExpansion)
   {
      if(close < ema21)
      {
         double prob = 0.62;
         double rr   = 2.0;

         // Target: prior BB low peak ("unfinished business" below)
         double priorTroughTarget = 1e10;
         int bbH = iBands(TradeSymbol, PERIOD_D1, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
         if(bbH != INVALID_HANDLE) {
            double lBuf[];
            if(CopyBuffer(bbH, 2, 1, FibLookback, lBuf) == FibLookback)
               for(int i = 1; i < FibLookback; i++)
                  priorTroughTarget = MathMin(priorTroughTarget, lBuf[i]);
            IndicatorRelease(bbH);
         }
         if(priorTroughTarget >= close || priorTroughTarget == 1e10)
            priorTroughTarget = close - StopLossPts * rr * pt;

         slPrice   = MathMax(ema21, close) + StopLossPts * pt;
         tpPrice   = priorTroughTarget;
         lot       = CalcLot(StopLossPts, prob, rr);
         direction = "SHORT (Expansion Down — trend continuation)";
         comment   = "SwingBB|EXP_DN|SHORT";
         g_lastSignal = signalKey;

         LogSignalCard(env, direction, close, slPrice, tpPrice,
                       lot, prob, rr, 0, tpPrice, 0,
                       upper, middle, lower, ema8, ema21, ema34);
         PlaceTrade(ORDER_TYPE_SELL, lot, slPrice, tpPrice, comment);
         return;
      }
   }

   // ══════════════════════════════════════════════════════════════════
   // ENVIRONMENT 3a: MEAN REVERSION BEAR
   // Trigger: daily close below 30% fib → target 50%
   // ══════════════════════════════════════════════════════════════════
   if(env == ENV_MEAN_REV_BEAR && AllowMeanRev)
   {
      // Smaller size if going against primary trend (price still above ema34)
      double prob = (close > ema34) ? 0.58 : 0.62;
      double rr   = 2.0;

      slPrice   = fibHigh + StopLossPts * pt;   // stop above last expansion high
      tpPrice   = level50;                       // 50% fib is the target
      lot       = CalcLot(StopLossPts, prob, rr);
      direction = "SHORT (Mean Reversion Bear — 30% trigger → 50% target)";
      comment   = "SwingBB|MR_BEAR|SHORT";
      g_lastSignal = signalKey;

      LogSignalCard(env, direction, close, slPrice, tpPrice,
                    lot, prob, rr, level30, level50, level70,
                    upper, middle, lower, ema8, ema21, ema34);
      PlaceTrade(ORDER_TYPE_SELL, lot, slPrice, tpPrice, comment);
      return;
   }

   // ══════════════════════════════════════════════════════════════════
   // ENVIRONMENT 3b: MEAN REVERSION BULL
   // Trigger: daily close above 70% fib (30% off low) → target 50%
   // ══════════════════════════════════════════════════════════════════
   if(env == ENV_MEAN_REV_BULL && AllowMeanRev)
   {
      double prob = (close < ema34) ? 0.58 : 0.62;
      double rr   = 2.0;

      slPrice   = fibLow  - StopLossPts * pt;   // stop below last expansion low
      tpPrice   = level50;
      lot       = CalcLot(StopLossPts, prob, rr);
      direction = "LONG (Mean Reversion Bull — 70% trigger → 50% target)";
      comment   = "SwingBB|MR_BULL|LONG";
      g_lastSignal = signalKey;

      LogSignalCard(env, direction, close, slPrice, tpPrice,
                    lot, prob, rr, level30, level50, level70,
                    upper, middle, lower, ema8, ema21, ema34);
      PlaceTrade(ORDER_TYPE_BUY, lot, slPrice, tpPrice, comment);
      return;
   }
}

//+------------------------------------------------------------------+
//| Chart comment — environment display                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lp,
                  const double &dp, const string &sp) {}

void OnDeinit(const int reason)
{
   Comment("");
   PrintFormat("SwingBBEA removed. Last environment: %s  Reason: %d",
               EnvName(g_lastEnv), reason);
}
//+------------------------------------------------------------------+
