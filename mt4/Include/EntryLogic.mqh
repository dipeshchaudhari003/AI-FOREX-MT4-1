//+------------------------------------------------------------------+
//| EntryLogic.mqh                                                   |
//| GoldPilotAI Enterprise v3.0 - Strategy Layer                     |
//| Entry signal generation with comprehensive filtering             |
//+------------------------------------------------------------------+
#ifndef __ENTRYLOGIC_MQH__
#define __ENTRYLOGIC_MQH__

#include "Config.mqh"
#include "Globals.mqh"
#include "Indicators.mqh"
#include "Filters.mqh"
#include "Utilities.mqh"

//====================================================================
// ENTRY LOGIC CONSTANTS
//====================================================================
#define SIGNAL_HOLD    0
#define SIGNAL_BUY     1
#define SIGNAL_SELL   -1

//====================================================================
// ENTRY CONFIRMATION STRUCTURES
//====================================================================
struct EntryConditions
{
   bool TrendOK;
   bool ATRFilterOK;
   bool ADXFilterOK;
   bool SpreadFilterOK;
   bool SessionFilterOK;
   bool LossFilterOK;
   bool CooldownOK;
   bool MaxTradesOK;
   bool BollingerOK;
   bool RSIFilterOK;
   bool StochasticOK;
   bool ConfidenceOK;
   bool CandleBodyOK;
};

//====================================================================
// ENTRY BUFFER - Prevents false signals on same bar
//====================================================================
datetime lastSignalBar = 0;

//====================================================================
// PRE-ENTRY CHECKS
//====================================================================

//--------------------------------------------------------------------
// Check: One Trade At A Time
//--------------------------------------------------------------------
bool CheckOneTradeAtATime()
{
   return (OrdersTotal() == 0);
}

//--------------------------------------------------------------------
// Check: Cooldown Period
//--------------------------------------------------------------------
bool CheckCooldown()
{
   if(lastTradeTime == 0) return true;
   
   int secondsSinceLastTrade = (int)(TimeCurrent() - lastTradeTime);
   return (secondsSinceLastTrade >= CooldownSeconds);
}

//--------------------------------------------------------------------
// Check: Maximum Trades Per Day
//--------------------------------------------------------------------
bool CheckMaxTradesPerDay()
{
   if(TodayTrades >= MaxTradesPerDay)
      return false;
   
   return true;
}

//--------------------------------------------------------------------
// Check: Signal Not On Same Bar
//--------------------------------------------------------------------
bool CheckNewBar()
{
   datetime currentBar = iTime(Symbol(), EntryTF, 1);
   
   if(currentBar == lastSignalBar)
      return false;
   
   return true;
}

//====================================================================
// ENTRY SIGNAL GENERATION
//====================================================================

//--------------------------------------------------------------------
// Bollinger Bands Pullback Entry (Buy)
//--------------------------------------------------------------------
bool BollingerBuySignal()
{
   // Price touches lower band - pullback entry
   if(CurrClose <= BBLower)
   {
      // Confirm with upward momentum
      if(CurrClose > CurrOpen) // Bullish candle
      {
         return true;
      }
   }
   
   // Price above lower band but pulled back
   if(CurrClose >= BBLower && CurrClose <= BBMiddle)
   {
      if(EMA20 > EMA50) // Short-term uptrend
      {
         return true;
      }
   }
   
   return false;
}

//--------------------------------------------------------------------
// Bollinger Bands Pullback Entry (Sell)
//--------------------------------------------------------------------
bool BollingerSellSignal()
{
   // Price touches upper band - pullback entry
   if(CurrClose >= BBUpper)
   {
      // Confirm with downward momentum
      if(CurrClose < CurrOpen) // Bearish candle
      {
         return true;
      }
   }
   
   // Price below upper band but pulled back
   if(CurrClose <= BBUpper && CurrClose >= BBMiddle)
   {
      if(EMA20 < EMA50) // Short-term downtrend
      {
         return true;
      }
   }
   
   return false;
}

//--------------------------------------------------------------------
// RSI Filter (Oversold/Overbought)
//--------------------------------------------------------------------
bool RSIFilterBuy()
{
   // Oversold but recovering
   return (RSI <= RSIOversold) && (RSI > RSIOversold - 10);
}

bool RSIFilterSell()
{
   // Overbought but declining
   return (RSI >= RSIOverbought) && (RSI < RSIOverbought + 10);
}

//--------------------------------------------------------------------
// Stochastic Confirmation
//--------------------------------------------------------------------
bool StochasticConfirmBuy()
{
   // Stochastic in oversold, looking for crossover
   if(StochMain < StochOversold)
   {
      return true;
   }
   
   // Stochastic crossed above signal line
   if(StochMain > StochSignal && 
      iStochastic(Symbol(), EntryTF, StochPeriod, 3, 3, 
                  MODE_SMA, 0, 0, 0) <= StochMain)
   {
      return true;
   }
   
   return false;
}

bool StochasticConfirmSell()
{
   // Stochastic in overbought, looking for crossover
   if(StochMain > StochOverbought)
   {
      return true;
   }
   
   // Stochastic crossed below signal line
   if(StochMain < StochSignal && 
      iStochastic(Symbol(), EntryTF, StochPeriod, 3, 3, 
                  MODE_SMA, 0, 0, 0) >= StochMain)
   {
      return true;
   }
   
   return false;
}

//--------------------------------------------------------------------
// Candle Body Filter
//--------------------------------------------------------------------
bool CandleBodyFilter()
{
   double bodyPoints = MathAbs(CurrClose - CurrOpen) / Point;
   return (bodyPoints >= MinCandleBodyPoints);
}

//--------------------------------------------------------------------
// Confidence Score Filter
//--------------------------------------------------------------------
bool ConfidenceScoreFilter()
{
   return (ConfidenceScore >= MinConfidenceRequired);
}

//====================================================================
// ENTRY CONDITIONS EVALUATION
//====================================================================

EntryConditions EvaluateEntryConditions()
{
   EntryConditions cond;
   
   cond.TrendOK        = (TrendFilterBuy() || TrendFilterSell());
   cond.ATRFilterOK    = ATRFilter();
   cond.ADXFilterOK    = ADXFilter();
   cond.SpreadFilterOK = SpreadFilter();
   cond.SessionFilterOK= SessionFilter();
   cond.LossFilterOK   = LossFilter();
   cond.CooldownOK     = CheckCooldown();
   cond.MaxTradesOK    = CheckMaxTradesPerDay();
   cond.BollingerOK    = (BollingerBuySignal() || BollingerSellSignal());
   cond.RSIFilterOK    = (RSIFilterBuy() || RSIFilterSell());
   cond.StochasticOK   = (StochasticConfirmBuy() || StochasticConfirmSell());
   cond.ConfidenceOK   = ConfidenceScoreFilter();
   cond.CandleBodyOK   = CandleBodyFilter();
   
   return cond;
}

//====================================================================
// MASTER ENTRY SIGNAL GENERATOR
//====================================================================

int GenerateEntrySignal()
{
   //---
   // Check basic pre-entry conditions
   //---
   if(!CheckOneTradeAtATime())
      return SIGNAL_HOLD;
   
   if(!CheckNewBar())
      return SIGNAL_HOLD;
   
   if(!CheckCooldown())
      return SIGNAL_HOLD;
   
   if(!CheckMaxTradesPerDay())
      return SIGNAL_HOLD;
   
   //---
   // Update indicators before analysis
   //---
   UpdateIndicators();
   Spread = MarketInfo(Symbol(), MODE_SPREAD);
   
   //---
   // Evaluate all conditions
   //---
   EntryConditions cond = EvaluateEntryConditions();
   
   //---
   // Check master filters first
   //---
   if(!AllowTrading())
      return SIGNAL_HOLD;
   
   //---
   // BUY Signal Generation
   //---
   if(TrendFilterBuy() && 
      BollingerBuySignal() && 
      RSIFilterBuy() && 
      StochasticConfirmBuy() && 
      cond.CandleBodyOK && 
      cond.ConfidenceOK)
   {
      LastSignal = SIGNAL_BUY;
      lastSignalBar = iTime(Symbol(), EntryTF, 1);
      return SIGNAL_BUY;
   }
   
   //---
   // SELL Signal Generation
   //---
   if(TrendFilterSell() && 
      BollingerSellSignal() && 
      RSIFilterSell() && 
      StochasticConfirmSell() && 
      cond.CandleBodyOK && 
      cond.ConfidenceOK)
   {
      LastSignal = SIGNAL_SELL;
      lastSignalBar = iTime(Symbol(), EntryTF, 1);
      return SIGNAL_SELL;
   }
   
   return SIGNAL_HOLD;
}

//====================================================================
// DEBUG LOGGING (Optional - for development)
//====================================================================

void LogEntryConditions(EntryConditions &cond)
{
   if(DebugEntryLogic)
   {
      Print("===== ENTRY CONDITIONS =====");
      Print("Trend:    ", cond.TrendOK);
      Print("ATR:      ", cond.ATRFilterOK);
      Print("ADX:      ", cond.ADXFilterOK);
      Print("Spread:   ", cond.SpreadFilterOK);
      Print("Session:  ", cond.SessionFilterOK);
      Print("LossStop: ", cond.LossFilterOK);
      Print("Cooldown: ", cond.CooldownOK);
      Print("MaxTrade: ", cond.MaxTradesOK);
      Print("Bollinger:", cond.BollingerOK);
      Print("RSI:      ", cond.RSIFilterOK);
      Print("Stoch:    ", cond.StochasticOK);
      Print("Confid:   ", cond.ConfidenceOK);
      Print("CandleBdy:", cond.CandleBodyOK);
      Print("===========================");
   }
}

#endif // __ENTRYLOGIC_MQH__
