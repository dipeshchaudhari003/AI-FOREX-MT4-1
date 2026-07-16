#ifndef __MLDATAEXPORTER_MQH__
#define __MLDATAEXPORTER_MQH__

datetime LastExportBar = 0;

//------------------------------------------------------
// Export latest candles for Python ML
//------------------------------------------------------
void ExportMarketData()
{
   datetime currentBar = iTime(Symbol(), PERIOD_M1, 0);

   // Export only once per new candle
   if(currentBar == LastExportBar)
      return;

   LastExportBar = currentBar;

   int handle = FileOpen(
      "xau_rates.csv",
      FILE_CSV | FILE_WRITE,
      ';'
   );

   if(handle == INVALID_HANDLE)
   {
      Print("ERROR : Cannot create xau_rates.csv");
      return;
   }

   // Export oldest -> newest
   for(int i = 300; i >= 0; i--)
   {
      FileWrite(
         handle,

         TimeToString(iTime(Symbol(),PERIOD_M1,i),TIME_DATE|TIME_MINUTES),

         DoubleToString(iOpen(Symbol(),PERIOD_M1,i),Digits),

         DoubleToString(iHigh(Symbol(),PERIOD_M1,i),Digits),

         DoubleToString(iLow(Symbol(),PERIOD_M1,i),Digits),

         DoubleToString(iClose(Symbol(),PERIOD_M1,i),Digits),

         iVolume(Symbol(),PERIOD_M1,i)
      );
   }

   FileClose(handle);

   Print("ML Export Updated : ",
         TimeToString(currentBar,TIME_DATE|TIME_SECONDS));
}

#endif