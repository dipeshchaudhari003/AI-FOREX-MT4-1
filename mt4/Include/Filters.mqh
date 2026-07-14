//+------------------------------------------------------------------+
//| Filters.mqh                                                      |
//| GoldPilotAI Enterprise v3.0                                      |
//+------------------------------------------------------------------+
#ifndef __FILTERS_MQH__
#define __FILTERS_MQH__

//====================================================
// Spread Filter
//====================================================
bool SpreadFilter()
{
   return (Spread <= MaxSpreadPoints);
}

//====================================================
// ATR Filter
//====================================================
bool ATRFilter()
{
   return (ATR >= MinATRPoints);
}

//====================================================
// ADX Filter
//====================================================
bool ADXFilter()
{
   return (ADX >= MinADX);
}

//====================================================
// Trend Filter
//====================================================
bool TrendFilterBuy()
{
   return (EMA20_M15 > EMA50_M15 &&
           EMA50 > EMA200);
}

bool TrendFilterSell()
{
   return (EMA20_M15 < EMA50_M15 &&
           EMA50 < EMA200);
}

//====================================================
// Session Filter
//====================================================
bool SessionFilter()
{
   int h = TimeHour(TimeCurrent());

   return (h >= LondonOpenHour &&
           h <= NewYorkCloseHour);
}

//====================================================
// Consecutive Loss Filter
//====================================================
bool LossFilter()
{
   return (ConsecutiveLosses < MaxConsecutiveLosses);
}

//====================================================
// MASTER FILTER
//====================================================
bool AllowTrading()
{
   if(!SpreadFilter()) return false;
   if(!ATRFilter()) return false;
   if(!ADXFilter()) return false;
   if(!SessionFilter()) return false;
   if(!LossFilter()) return false;

   return true;
}

#endif