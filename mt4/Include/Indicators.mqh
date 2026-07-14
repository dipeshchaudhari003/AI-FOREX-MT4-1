//+------------------------------------------------------------------+
//| Indicators.mqh                                                   |
//| GoldPilotAI Enterprise v3.0                                      |
//+------------------------------------------------------------------+
#ifndef __INDICATORS_MQH__
#define __INDICATORS_MQH__

#include "Config.mqh"
#include "Globals.mqh"

void UpdateIndicators()
{
   //=========================================================
   // ENTRY TIMEFRAME (Default M1)
   //=========================================================

   CurrOpen  = iOpen(Symbol(), EntryTF, 1);
   CurrHigh  = iHigh(Symbol(), EntryTF, 1);
   CurrLow   = iLow(Symbol(), EntryTF, 1);
   CurrClose = iClose(Symbol(), EntryTF, 1);

   PrevOpen  = iOpen(Symbol(), EntryTF, 2);
   PrevHigh  = iHigh(Symbol(), EntryTF, 2);
   PrevLow   = iLow(Symbol(), EntryTF, 2);
   PrevClose = iClose(Symbol(), EntryTF, 2);

   //=========================================================
   // ENTRY EMA (M1)
   //=========================================================

   EMA9 =
      iMA(Symbol(), EntryTF, 9, 0, MODE_EMA, PRICE_CLOSE, 1);

   EMA20 =
      iMA(Symbol(), EntryTF, 20, 0, MODE_EMA, PRICE_CLOSE, 1);

   EMA21 =
      iMA(Symbol(), EntryTF, 21, 0, MODE_EMA, PRICE_CLOSE, 1);

   //=========================================================
   // TREND EMA (M5)
   //=========================================================

   EMA50 =
      iMA(Symbol(), TrendTF, 50, 0, MODE_EMA, PRICE_CLOSE, 1);

   //=========================================================
   // LONG TERM TREND (M15)
   //=========================================================

   EMA200 =
      iMA(Symbol(), ConfirmTF, 200, 0, MODE_EMA, PRICE_CLOSE, 1);

   EMA20_M15 =
      iMA(Symbol(), ConfirmTF, 20, 0, MODE_EMA, PRICE_CLOSE, 1);

   EMA50_M15 =
      iMA(Symbol(), ConfirmTF, 50, 0, MODE_EMA, PRICE_CLOSE, 1);

   //=========================================================
   // ATR (Trend TF)
   //=========================================================

   ATR =
      iATR(Symbol(),
           TrendTF,
           ATRPeriod,
           1) / Point;

   //=========================================================
   // ADX (Trend TF)
   //=========================================================

   ADX =
      iADX(Symbol(),
           TrendTF,
           ADXPeriod,
           PRICE_CLOSE,
           MODE_MAIN,
           1);

   //=========================================================
   // BOLLINGER (Entry TF)
   //=========================================================

   BBUpper =
      iBands(Symbol(),
             EntryTF,
             BollingerPeriod,
             BollingerDeviation,
             0,
             PRICE_CLOSE,
             MODE_UPPER,
             1);

   BBMiddle =
      iBands(Symbol(),
             EntryTF,
             BollingerPeriod,
             BollingerDeviation,
             0,
             PRICE_CLOSE,
             MODE_MAIN,
             1);

   BBLower =
      iBands(Symbol(),
             EntryTF,
             BollingerPeriod,
             BollingerDeviation,
             0,
             PRICE_CLOSE,
             MODE_LOWER,
             1);

   //=========================================================
   // STOCHASTIC (Entry TF)
   //=========================================================

   StochMain =
      iStochastic(Symbol(),
                  EntryTF,
                  StochPeriod,
                  3,
                  3,
                  MODE_SMA,
                  0,
                  MODE_MAIN,
                  1);

   StochSignal =
      iStochastic(Symbol(),
                  EntryTF,
                  StochPeriod,
                  3,
                  3,
                  MODE_SMA,
                  0,
                  MODE_SIGNAL,
                  1);

   //=========================================================
   // RSI (Entry TF)
   //=========================================================

   RSI =
      iRSI(Symbol(),
           EntryTF,
           RSIPeriod,
           PRICE_CLOSE,
           1);

   //=========================================================
   // SPREAD
   //=========================================================

   Spread = (Ask - Bid) / Point;
}

#endif