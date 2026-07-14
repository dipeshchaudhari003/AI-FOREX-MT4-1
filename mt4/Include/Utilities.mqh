//+------------------------------------------------------------------+
//| Utilities.mqh                                                    |
//+------------------------------------------------------------------+
#ifndef __UTILITIES_MQH__
#define __UTILITIES_MQH__

double PointsBetween(double p1,double p2)
{
   return MathAbs(p1-p2)/Point;
}

double CandleBodyPoints()
{
   return MathAbs(
      iClose(Symbol(),PERIOD_M1,1)-
      iOpen(Symbol(),PERIOD_M1,1)
   )/Point;
}

double CandleRangePoints()
{
   return MathAbs(
      iHigh(Symbol(),PERIOD_M1,1)-
      iLow(Symbol(),PERIOD_M1,1)
   )/Point;
}

bool IsBullish()
{
   return iClose(Symbol(),PERIOD_M1,1)>
          iOpen(Symbol(),PERIOD_M1,1);
}

bool IsBearish()
{
   return iClose(Symbol(),PERIOD_M1,1)<
          iOpen(Symbol(),PERIOD_M1,1);
}

#endif