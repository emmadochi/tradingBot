//+------------------------------------------------------------------+
//|                                        Deriv_PriceAction_EA.mq5  |
//|                             Copyright 2026, RadarBot Automation  |
//|                       https://github.com/emmadochi/tradingBot    |
//+------------------------------------------------------------------+
#property copyright   "RadarBot Automation"
#property link        "https://github.com/emmadochi/tradingBot"
#property version     "2.00"
#property description "Top-Down Price Action EA for Deriv Synthetic Indices"
#property description "Trades Volatility 25 Index & Volatility 75 Index"
#property description "HTF S/R + Candlestick confirmation + 1:2 R:R SL/TP"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input Parameters
input group "=== STRATEGY TIMEFRAMES ==="
input ENUM_TIMEFRAMES InpHTF              = PERIOD_H1;       // Higher Timeframe (Trend & S/R)
input ENUM_TIMEFRAMES InpLTF              = PERIOD_M15;      // Lower Timeframe (Entry Trigger)
input int             InpHTFCandles       = 100;             // HTF History Bars for S/R
input double          InpSRClusteringPct  = 0.6;             // S/R Cluster Tolerance (%)

input group "=== RISK & EXECUTION ==="
input double          InpLotSize          = 0.50;            // Fixed Lot Size (e.g. 0.5 for Vol25, 0.005 for Vol75)
input double          InpMinRR            = 2.0;             // Minimum Risk to Reward Ratio (1:X)
input double          InpATRBufferMult    = 0.5;             // SL Buffer (ATR Multiplier)
input int             InpMaxSpreadPoints  = 200;             // Max Spread Filter (Points)
input ulong           InpMagicNumber      = 882575;          // EA Magic Number
input string          InpTradeComment     = "RadarBot-PA";   // Trade Comment

input group "=== NOTIFICATIONS ==="
input bool            InpSendAlert        = true;            // Terminal Sound & Popup Alert
input bool            InpSendPushNotify   = true;            // Push Notification to MT5 Mobile App

//--- Global Objects
CTrade         m_trade;
CSymbolInfo    m_symbol;
CPositionInfo  m_position;

//--- Indicator Handles
int            m_handle_htf_ema_fast;
int            m_handle_htf_ema_slow;
int            m_handle_ltf_atr;

//--- Dynamic Arrays for S/R
double         m_support_levels[];
double         m_resistance_levels[];
datetime       m_last_htf_calc_time = 0;
datetime       m_last_ltf_bar_time  = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!m_symbol.Name(_Symbol))
     {
      Print("[-] Failed to initialize symbol: ", _Symbol);
      return INIT_FAILED;
     }
   m_symbol.Refresh();

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(20);
   
   // Set fill type fallback for Deriv servers
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   // HTF Trend EMAs (20 & 50)
   m_handle_htf_ema_fast = iMA(_Symbol, InpHTF, 20, 0, MODE_EMA, PRICE_CLOSE);
   m_handle_htf_ema_slow = iMA(_Symbol, InpHTF, 50, 0, MODE_EMA, PRICE_CLOSE);

   // LTF ATR (14)
   m_handle_ltf_atr = iATR(_Symbol, InpLTF, 14);

   if(m_handle_htf_ema_fast == INVALID_HANDLE || 
      m_handle_htf_ema_slow == INVALID_HANDLE || 
      m_handle_ltf_atr == INVALID_HANDLE)
     {
      Print("[-] Failed to create indicator handles.");
      return INIT_FAILED;
     }

   Print("[+] RadarBot EA Initialized successfully on ", _Symbol);
   UpdateHTFLevels();
   UpdateChartComment("Initialized - Monitoring Price Action");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(m_handle_htf_ema_fast);
   IndicatorRelease(m_handle_htf_ema_slow);
   IndicatorRelease(m_handle_ltf_atr);
   Comment("");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Check for a new closed LTF candle
   datetime current_bar_time = iTime(_Symbol, InpLTF, 0);
   if(current_bar_time == m_last_ltf_bar_time)
      return; // Only process on new candle open to avoid intra-bar false triggers

   m_last_ltf_bar_time = current_bar_time;

   // 2. Refresh symbol data
   if(!m_symbol.RefreshRates())
      return;

   // 3. Update HTF Support/Resistance every new HTF bar
   datetime current_htf_time = iTime(_Symbol, InpHTF, 0);
   if(current_htf_time != m_last_htf_calc_time)
     {
      UpdateHTFLevels();
      m_last_htf_calc_time = current_htf_time;
     }

   // 4. Spread filter
   if(m_symbol.Spread() > InpMaxSpreadPoints)
     {
      UpdateChartComment("Spread too high: " + IntegerToString(m_symbol.Spread()));
      return;
     }

   // 5. Evaluate setup and trigger entry if no open position exists
   if(!HasOpenPosition())
     {
      EvaluateEntry();
     }
   else
     {
      UpdateChartComment("Position Active — Managing Trade");
     }
  }

//+------------------------------------------------------------------+
//| Check if an active position already exists for this symbol & magic|
//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
            return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Identify HTF Support and Resistance Pivot Zones                  |
//+------------------------------------------------------------------+
void UpdateHTFLevels()
  {
   MqlRates htf_rates[];
   ArraySetAsSeries(htf_rates, true);
   int copied = CopyRates(_Symbol, InpHTF, 1, InpHTFCandles, htf_rates);
   if(copied < 10)
      return;

   double raw_supports[];
   double raw_resistances[];
   ArrayResize(raw_supports, 0);
   ArrayResize(raw_resistances, 0);

   // Swing High / Low detection with 2-bar left/right fractals
   for(int i = 2; i < copied - 2; i++)
     {
      // Swing High
      if(htf_rates[i].high > htf_rates[i+1].high && htf_rates[i].high > htf_rates[i+2].high &&
         htf_rates[i].high > htf_rates[i-1].high && htf_rates[i].high > htf_rates[i-2].high)
        {
         int sz = ArraySize(raw_resistances);
         ArrayResize(raw_resistances, sz + 1);
         raw_resistances[sz] = htf_rates[i].high;
        }
      // Swing Low
      if(htf_rates[i].low < htf_rates[i+1].low && htf_rates[i].low < htf_rates[i+2].low &&
         htf_rates[i].low < htf_rates[i-1].low && htf_rates[i].low < htf_rates[i-2].low)
        {
         int sz = ArraySize(raw_supports);
         ArrayResize(raw_supports, sz + 1);
         raw_supports[sz] = htf_rates[i].low;
        }
     }

   // Cluster and merge nearby levels
   ClusterLevels(raw_supports, m_support_levels, InpSRClusteringPct);
   ClusterLevels(raw_resistances, m_resistance_levels, InpSRClusteringPct);

   Print("[+] S/R Updated: ", ArraySize(m_support_levels), " Supports, ", ArraySize(m_resistance_levels), " Resistances.");
  }

//+------------------------------------------------------------------+
//| Cluster nearby levels within tolerance percentage                |
//+------------------------------------------------------------------+
void ClusterLevels(const double &raw[], double &clustered[], double tol_pct)
  {
   ArrayResize(clustered, 0);
   int n = ArraySize(raw);
   if(n == 0) return;

   double sorted[];
   ArrayCopy(sorted, raw);
   ArraySort(sorted);

   double current_group[];
   ArrayResize(current_group, 1);
   current_group[0] = sorted[0];

   for(int i = 1; i < n; i++)
     {
      double anchor = current_group[0];
      if(anchor > 0 && MathAbs(sorted[i] - anchor) / anchor * 100.0 <= tol_pct)
        {
         int gsz = ArraySize(current_group);
         ArrayResize(current_group, gsz + 1);
         current_group[gsz] = sorted[i];
        }
      else
        {
         // Average current group
         double sum = 0;
         for(int j = 0; j < ArraySize(current_group); j++) sum += current_group[j];
         int csz = ArraySize(clustered);
         ArrayResize(clustered, csz + 1);
         clustered[csz] = sum / ArraySize(current_group);

         // Start new group
         ArrayResize(current_group, 1);
         current_group[0] = sorted[i];
        }
     }

   // Add final group
   double sum = 0;
   for(int j = 0; j < ArraySize(current_group); j++) sum += current_group[j];
   int csz = ArraySize(clustered);
   ArrayResize(clustered, csz + 1);
   clustered[csz] = sum / ArraySize(current_group);
  }

//+------------------------------------------------------------------+
//| Evaluate LTF Candlestick Triggers at Key S/R Zones               |
//+------------------------------------------------------------------+
void EvaluateEntry()
  {
   MqlRates ltf_rates[];
   ArraySetAsSeries(ltf_rates, true);
   if(CopyRates(_Symbol, InpLTF, 0, 10, ltf_rates) < 5)
      return;

   // Get HTF Trend (EMA 20 vs EMA 50)
   double ema_fast[1], ema_slow[1];
   if(CopyBuffer(m_handle_htf_ema_fast, 0, 1, 1, ema_fast) <= 0 ||
      CopyBuffer(m_handle_htf_ema_slow, 0, 1, 1, ema_slow) <= 0)
      return;

   string htf_trend = "NEUTRAL";
   if(ema_fast[0] > ema_slow[0]) htf_trend = "BULLISH";
   else if(ema_fast[0] < ema_slow[0]) htf_trend = "BEARISH";

   // Read ATR for buffering
   double atr[1];
   if(CopyBuffer(m_handle_ltf_atr, 0, 1, 1, atr) <= 0)
      return;
   double current_atr = atr[0];

   MqlRates c1 = ltf_rates[1]; // Most recently closed candle
   MqlRates c2 = ltf_rates[2]; // Previous candle
   MqlRates c3 = ltf_rates[3]; // Pre-previous candle

   double close_p = c1.close;
   double open_p  = c1.open;
   double high_p  = c1.high;
   double low_p   = c1.low;
   double body    = MathAbs(close_p - open_p);
   double rng     = high_p - low_p;
   if(rng <= 0) return;

   string pattern = "";
   string signal  = "";

   // --- BULLISH PATTERNS (At Support) ---
   // 1. Hammer
   bool is_hammer = (low_p + rng * 0.35 >= MathMin(open_p, close_p)) && 
                    ((high_p - MathMax(open_p, close_p)) <= rng * 0.20) &&
                    (body <= rng * 0.40);
   // 2. Bullish Engulfing
   bool is_bull_engulf = (c2.close < c2.open) && (c1.close > c1.open) &&
                         (c1.close >= c2.open) && (c1.open <= c2.close);
   // 3. Morning Star
   double body2 = MathAbs(c2.close - c2.open);
   double rng2  = c2.high - c2.low;
   bool is_morning_star = (c3.close < c3.open) && (c1.close > c1.open) &&
                          (body2 <= rng2 * 0.35) && (c1.close >= (c3.open + c3.close) / 2.0);

   if(is_hammer)         { pattern = "Hammer"; signal = "BUY"; }
   else if(is_bull_engulf) { pattern = "Bullish Engulfing"; signal = "BUY"; }
   else if(is_morning_star){ pattern = "Morning Star"; signal = "BUY"; }

   // --- BEARISH PATTERNS (At Resistance) ---
   // 1. Shooting Star
   bool is_shooting_star = (high_p - rng * 0.35 <= MathMax(open_p, close_p)) &&
                           ((MathMin(open_p, close_p) - low_p) <= rng * 0.20) &&
                           (body <= rng * 0.40);
   // 2. Bearish Engulfing
   bool is_bear_engulf = (c2.close > c2.open) && (c1.close < c1.open) &&
                         (c1.open >= c2.close) && (c1.close <= c2.open);
   // 3. Evening Star
   bool is_evening_star = (c3.close > c3.open) && (c1.close < c1.open) &&
                          (body2 <= rng2 * 0.35) && (c1.close <= (c3.open + c3.close) / 2.0);

   if(is_shooting_star)    { pattern = "Shooting Star"; signal = "SELL"; }
   else if(is_bear_engulf) { pattern = "Bearish Engulfing"; signal = "SELL"; }
   else if(is_evening_star){ pattern = "Evening Star"; signal = "SELL"; }

   if(signal == "")
     {
      UpdateChartComment("Scanning for S/R confirmation (Trend: " + htf_trend + ")");
      return;
     }

   // --- S/R PROXIMITY CHECK ---
   double level_used = 0.0;
   bool near_sr = false;

   if(signal == "BUY")
     {
      for(int i = 0; i < ArraySize(m_support_levels); i++)
        {
         double dist = MathAbs(close_p - m_support_levels[i]);
         if(dist <= current_atr * 1.5 || dist / close_p * 100.0 <= InpSRClusteringPct)
           {
            near_sr = true;
            level_used = m_support_levels[i];
            break;
           }
        }
     }
   else if(signal == "SELL")
     {
      for(int i = 0; i < ArraySize(m_resistance_levels); i++)
        {
         double dist = MathAbs(close_p - m_resistance_levels[i]);
         if(dist <= current_atr * 1.5 || dist / close_p * 100.0 <= InpSRClusteringPct)
           {
            near_sr = true;
            level_used = m_resistance_levels[i];
            break;
           }
        }
     }

   if(!near_sr)
     {
      UpdateChartComment("Pattern detected (" + pattern + ") but NOT at Key S/R. Ignored.");
      return;
     }

   // --- HTF TREND CONFLUENCE FILTER ---
   if(signal == "BUY" && htf_trend == "BEARISH")
     {
      UpdateChartComment("BUY setup at Support filtered out by BEARISH HTF Trend.");
      return;
     }
   if(signal == "SELL" && htf_trend == "BULLISH")
     {
      UpdateChartComment("SELL setup at Resistance filtered out by BULLISH HTF Trend.");
      return;
     }

   // --- CALCULATE SL & TP WITH 1:2 MIN R:R ---
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double buffer = current_atr * InpATRBufferMult;
   double entry_price = (signal == "BUY") ? ask : bid;
   double sl = 0.0;
   double tp = 0.0;

   // 3-bar lowest/highest
   double pattern_low  = MathMin(c1.low, MathMin(c2.low, c3.low));
   double pattern_high = MathMax(c1.high, MathMax(c2.high, c3.high));

   if(signal == "BUY")
     {
      sl = MathMin(level_used, pattern_low) - buffer;
      double risk = entry_price - sl;
      if(risk <= 0) return;
      tp = entry_price + (risk * InpMinRR);
     }
   else
     {
      sl = MathMax(level_used, pattern_high) + buffer;
      double risk = sl - entry_price;
      if(risk <= 0) return;
      tp = entry_price - (risk * InpMinRR);
     }

   // Normalize prices to symbol digits
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   entry_price = NormalizeDouble(entry_price, _Digits);

   // --- EXECUTE ORDER ---
   bool res = false;
   if(signal == "BUY")
      res = m_trade.Buy(InpLotSize, _Symbol, ask, sl, tp, InpTradeComment);
   else
      res = m_trade.Sell(InpLotSize, _Symbol, bid, sl, tp, InpTradeComment);

   if(res)
     {
      string alert_text = StringFormat("⚡ RadarBot %s on %s | Pattern: %s | Entry: %.4f | SL: %.4f | TP: %.4f",
                                       signal, _Symbol, pattern, entry_price, sl, tp);
      Print(alert_text);

      if(InpSendAlert)
         Alert(alert_text);
      if(InpSendPushNotify)
         SendNotification(alert_text);

      UpdateChartComment("ORDER EXECUTED: " + signal + " (" + pattern + ")");
     }
   else
     {
      Print("[-] Order execution failed. Retcode: ", m_trade.ResultRetcode(), " Desc: ", m_trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
//| Update clean on-chart visual display HUD                         |
//+------------------------------------------------------------------+
void UpdateChartComment(string status_text)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   string s = "===========================================\n" +
              "       RADARBOT MT5 PRICE ACTION EA        \n" +
              "===========================================\n" +
              " Symbol:         " + _Symbol + "\n" +
              " Balance:        $" + DoubleToString(balance, 2) + " USD\n" +
              " Equity:         $" + DoubleToString(equity, 2) + " USD\n" +
              " Timeframe:      HTF: " + EnumToString(InpHTF) + " | LTF: " + EnumToString(InpLTF) + "\n" +
              " Key Supports:   " + IntegerToString(ArraySize(m_support_levels)) + " active levels\n" +
              " Key Resistance: " + IntegerToString(ArraySize(m_resistance_levels)) + " active levels\n" +
              " Status:         " + status_text + "\n" +
              "===========================================";
   Comment(s);
  }
//+------------------------------------------------------------------+
