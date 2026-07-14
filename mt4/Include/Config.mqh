//+------------------------------------------------------------------+
//| Config.mqh                                                       |
//| GoldPilotAI Enterprise v3.0                                      |
//+------------------------------------------------------------------+
#ifndef __CONFIG_MQH__
#define __CONFIG_MQH__

//==============================
// GENERAL
//==============================
input double LotSize               = 0.01;
input int    MagicNumber           = 202501;


//==============================
// TP / SL
//==============================
input int DefaultTakeProfit        = 50;
input int DefaultStopLoss          = 100;

input int BreakEvenPoints          = 10;

//==============================
// STRUCTURE SL
//==============================
input int ML_SL_Lookback           = 10;
input int ML_MinSL_Points          = 120;
input int ML_MaxSL_Points          = 350;

//==============================
// MANUAL
//==============================
input int ManualSLLookback         = 8;
input int ManualMaxSL              = 400;
input int ManualBreakEven          = 15;

//==============================
// FILTERS
//==============================
input int ATRPeriod                = 14;
input int ATRMinimum               = 25;
input int ATRMaximum               = 180;

input int ADXPeriod                = 14;
input int ADXMinimum               = 22;

input int EMAFast                  = 20;
input int EMASlow                  = 50;
input int EMATrend                 = 200;

//==============================
// SESSION
//==============================
input int TradingStartHour         = 8;
input int TradingEndHour           = 21;

//==============================
// RISK
//==============================
input int MaxTradesPerDay          = 10;

//==============================
// TIMEFRAMES
//==============================
input ENUM_TIMEFRAMES EntryTF   = PERIOD_M1;   // Entry timeframe
input ENUM_TIMEFRAMES TrendTF   = PERIOD_M5;   // Trend filter
input ENUM_TIMEFRAMES ConfirmTF = PERIOD_M15;  // Higher timeframe confirmation

//==============================
// FILTERS
//==============================
input double MaxSpreadPoints = 150;
input double MinATRPoints = 80;
input double MinADX = 20;

//==============================
// Session
//==============================
input int LondonOpenHour = 8;
input int NewYorkCloseHour = 22;


//==============================
// Risk
//==============================

input int MaxConsecutiveLosses = 3;
input double MinConfidence      = 0.60;

#endif