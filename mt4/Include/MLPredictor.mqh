//+------------------------------------------------------------------+
//| MLPredictor.mqh                                                  |
//| GoldPilotAI Enterprise v3.0 - AI Layer                           |
//| Machine Learning signal prediction & Python integration          |
//+------------------------------------------------------------------+
#ifndef __MLPREDICTOR_MQH__
#define __MLPREDICTOR_MQH__

#include "Config.mqh"
#include "Globals.mqh"

//====================================================================
// ML SIGNAL STRUCTURE
//====================================================================
struct MLSignal
{
   int Signal;                    // 1=BUY, -1=SELL, 0=HOLD
   double Confidence;             // 0.0 to 1.0
   double BuyProbability;         // 0.0 to 1.0
   double SellProbability;        // 0.0 to 1.0
   double Score;                  // Raw score from model
   datetime Timestamp;            // When signal generated
   string Model;                  // Model name/version
   bool IsValid;                  // Validation status
   string ValidationError;        // Error message if invalid
};

//====================================================================
// FILE PATH CONSTANTS (Python Integration)
//====================================================================
#define SIGNAL_FILE_PATH        "xau_signal.txt"
#define CONFIDENCE_FILE_PATH    "xau_conf.txt"
#define BULLISH_PROB_FILE_PATH  "xau_bull_prob.txt"
#define BEARISH_PROB_FILE_PATH  "xau_bear_prob.txt"
#define SCORE_FILE_PATH         "xau_score.txt"
#define MODEL_INFO_FILE_PATH    "xau_model.txt"

//====================================================================
// SIGNAL FILE READING (From Python)
//====================================================================

//--------------------------------------------------------------------
// Read ML Signal from File (Python Output)
//--------------------------------------------------------------------
int ReadMLSignal()
{
   Print("==================================");
   Print("Reading ML Signal...");
   Print("File Name : ", SIGNAL_FILE_PATH);

   ResetLastError();

   int h = FileOpen(SIGNAL_FILE_PATH, FILE_READ|FILE_TXT);

   if(h == INVALID_HANDLE)
   {
      Print("FAILED TO OPEN FILE");
      Print("MT4 Error : ", GetLastError());
      return 0;
   }

   string signal_str = FileReadString(h);

   FileClose(h);

   Print("Raw Value : [", signal_str, "]");

   int signal = StrToInteger(signal_str);

   Print("Converted Signal : ", signal);

   Print("==================================");

   return signal;
}
//--------------------------------------------------------------------
// Read Confidence Score from File (Python Output)
//--------------------------------------------------------------------
double ReadMLConfidence()
{
   Print("Reading Confidence...");

   ResetLastError();

   int h = FileOpen(CONFIDENCE_FILE_PATH, FILE_READ|FILE_TXT);

   if(h==INVALID_HANDLE)
   {
      Print("Confidence File Missing");
      Print("Error=",GetLastError());
      return 0;
   }

   string s=FileReadString(h);

   FileClose(h);

   Print("Confidence Raw = [",s,"]");

   double conf=StrToDouble(s);

   Print("Confidence = ",DoubleToString(conf,2));

   return conf;
}

//--------------------------------------------------------------------
// Read Buy Probability from File (Python Output)
//--------------------------------------------------------------------
double ReadBullishProbability()
{
   int h = FileOpen(BULLISH_PROB_FILE_PATH, FILE_READ | FILE_TXT);
   
   if(h == INVALID_HANDLE)
      return 0.5;  // Default: 50% neutral
   
   string prob_str = FileReadString(h);
   FileClose(h);
   
   if(StringLen(prob_str) == 0)
      return 0.5;
   
   double prob = StrToDouble(prob_str);
   
   // Validate between 0 and 1
   if(prob < 0 || prob > 1)
      return 0.5;
   
   return prob;
}

//--------------------------------------------------------------------
// Read Sell Probability from File (Python Output)
//--------------------------------------------------------------------
double ReadBearishProbability()
{
   int h = FileOpen(BEARISH_PROB_FILE_PATH, FILE_READ | FILE_TXT);
   
   if(h == INVALID_HANDLE)
      return 0.5;  // Default: 50% neutral
   
   string prob_str = FileReadString(h);
   FileClose(h);
   
   if(StringLen(prob_str) == 0)
      return 0.5;
   
   double prob = StrToDouble(prob_str);
   
   // Validate between 0 and 1
   if(prob < 0 || prob > 1)
      return 0.5;
   
   return prob;
}

//--------------------------------------------------------------------
// Read Raw ML Score from File (Python Output)
//--------------------------------------------------------------------
double ReadMLScore()
{
   int h = FileOpen(SCORE_FILE_PATH, FILE_READ | FILE_TXT);
   
   if(h == INVALID_HANDLE)
      return 0.0;  // Default: neutral
   
   string score_str = FileReadString(h);
   FileClose(h);
   
   if(StringLen(score_str) == 0)
      return 0.0;
   
   double score = StrToDouble(score_str);
   return score;
}

//--------------------------------------------------------------------
// Read Model Information from File (Python Output)
//--------------------------------------------------------------------
string ReadModelInfo()
{
   int h = FileOpen(MODEL_INFO_FILE_PATH, FILE_READ | FILE_TXT);
   
   if(h == INVALID_HANDLE)
      return "Unknown";
   
   string model = FileReadString(h);
   FileClose(h);
   
   if(StringLen(model) == 0)
      return "Unknown";
   
   return model;
}

//====================================================================
// ML SIGNAL GENERATION & VALIDATION
//====================================================================

//--------------------------------------------------------------------
// Generate Complete ML Signal (All Data)
//--------------------------------------------------------------------
MLSignal GenerateMLSignal()
{
   Print("******** GenerateFinalSignal ENTERED ********");
   MLSignal signal;
   signal.IsValid = true;
   signal.ValidationError = "";
   
   //---
   // Read all ML data from files
   //---
   signal.Signal = ReadMLSignal();
   signal.Confidence = ReadMLConfidence();
   signal.BuyProbability = ReadBullishProbability();
   signal.SellProbability = ReadBearishProbability();
   signal.Score = ReadMLScore();
   signal.Model = ReadModelInfo();
   signal.Timestamp = TimeCurrent();
   
   Print("BuyProbability  = ", DoubleToString(signal.BuyProbability,4));
   Print("SellProbability = ", DoubleToString(signal.SellProbability,4));

   Print("========== ML OBJECT ==========");
   Print("Signal      = ", signal.Signal);
   Print("Confidence  = ", DoubleToString(signal.Confidence,2));
   Print("BuyProb     = ", DoubleToString(signal.BuyProbability,2));
   Print("SellProb    = ", DoubleToString(signal.SellProbability,2));
   Print("Score       = ", DoubleToString(signal.Score,2));
   Print("Model       = ", signal.Model);
   Print("===============================");

   //---
   // Validate signal is meaningful
   //---
   if(signal.Signal == 0)
   {
      Print("FAILED #1 -> Signal is HOLD");
      signal.IsValid = false;
      signal.ValidationError = "ML signal is HOLD (0)";
      return signal;
   }
   
   //---
   // Validate confidence meets minimum
   //---
   if(signal.Confidence < MinConfidenceRequired)
   {
      Print("FAILED #2 -> Confidence too low");
      signal.IsValid = false;
      signal.ValidationError = StringFormat(
         "Confidence too low: %.2f < %.2f",
         signal.Confidence, MinConfidenceRequired);
      return signal;
   }
   
   //---
   // Validate probabilities sum approximately to 1
   //---
   double probSum = signal.BuyProbability + signal.SellProbability;
   if(probSum < 0.95 || probSum > 1.05)  // Allow small margin for rounding
   {
      Print("⚠️ Probability sum unusual: ", DoubleToString(probSum, 3));
   }
   
   //---
   // Validate signal direction matches highest probability
   //---
   if(signal.Signal == 1 && signal.BuyProbability <= signal.SellProbability)
   {
      Print("FAILED #3 -> BUY probability mismatch");
      signal.IsValid = false;
      signal.ValidationError = "BUY signal but sell probability higher";
      return signal;
   }
   
   if(signal.Signal == -1 && signal.SellProbability <= signal.BuyProbability)
   {
      Print("FAILED #4 -> SELL probability mismatch");
      signal.IsValid = false;
      signal.ValidationError = "SELL signal but buy probability higher";
      return signal;
   }
   
   return signal;
}

//====================================================================
// CONFIDENCE FILTERING
//====================================================================

//--------------------------------------------------------------------
// Is ML Signal Confidence Acceptable?
//--------------------------------------------------------------------
bool IsMLSignalConfident(MLSignal &signal)
{
   if(!signal.IsValid)
      return false;
   
   if(signal.Confidence < MinConfidenceRequired)
      return false;
   
   return true;
}

//--------------------------------------------------------------------
// Get Confidence Level (Descriptive)
//--------------------------------------------------------------------
string GetConfidenceLevelText(double confidence)
{
   if(confidence >= 0.9)
      return "Very High";
   else if(confidence >= 0.75)
      return "High";
   else if(confidence >= 0.6)
      return "Moderate";
   else if(confidence >= 0.5)
      return "Low";
   else
      return "Very Low";
}

//====================================================================
// SIGNAL INTEGRATION WITH ENTRY LOGIC
//====================================================================

//--------------------------------------------------------------------
// Get ML-Enhanced Signal (Combines ML with Technical)
//--------------------------------------------------------------------
int GetMLEnhancedSignal(int technicalSignal, MLSignal &mlSignal)
{
   //---
   // If no technical signal, don't trade
   //---
   if(technicalSignal == 0)
      return 0;
   
   //---
   // If ML not confident, skip
   //---
   if(!IsMLSignalConfident(mlSignal))
   {
      Print("⚠️ ML signal not confident enough: ", 
            DoubleToString(mlSignal.Confidence, 2));
      return 0;
   }
   
   //---
   // If ML disagrees with technical, be cautious
   //---
   if(technicalSignal == 1 && mlSignal.Signal == -1)
   {
      Print("⚠️ ML disagrees: Technical=BUY, ML=SELL");
      return 0;  // Skip trade if conflicting signals
   }
   
   if(technicalSignal == -1 && mlSignal.Signal == 1)
   {
      Print("⚠️ ML disagrees: Technical=SELL, ML=BUY");
      return 0;  // Skip trade if conflicting signals
   }
   
   //---
   // Both agree: Execute signal with ML confidence level
   //---
   Print("✅ ML CONFIRMED: Signal=", technicalSignal, 
         " Confidence=", DoubleToString(mlSignal.Confidence, 2));
   
   return technicalSignal;
}

//====================================================================
// ML SIGNAL CACHING (Avoid Frequent File Reads)
//====================================================================

//--------------------------------------------------------------------
// Global ML Signal Cache
//--------------------------------------------------------------------
static MLSignal cachedMLSignal;
static datetime lastMLReadTime = 0;
static int mlReadCacheDuration = 5;  // Cache for 5 seconds

//--------------------------------------------------------------------
// Get ML Signal with Caching
//--------------------------------------------------------------------
MLSignal GetMLSignalCached()
{
   // Check if cache is still fresh
   int secondsSinceLastRead = (int)(TimeCurrent() - lastMLReadTime);
   
   if(secondsSinceLastRead < mlReadCacheDuration)
   {
      return cachedMLSignal;  // Return cached signal
   }
   
   // Cache expired, read fresh signal
   cachedMLSignal = GenerateMLSignal();
   lastMLReadTime = TimeCurrent();
   
   return cachedMLSignal;
}

//--------------------------------------------------------------------
// Force Refresh ML Signal Cache
//--------------------------------------------------------------------
void RefreshMLSignalCache()
{
   cachedMLSignal = GenerateMLSignal();
   lastMLReadTime = TimeCurrent();
}

//====================================================================
// ML SIGNAL LOGGING & DEBUGGING
//====================================================================

//--------------------------------------------------------------------
// Log Complete ML Signal Analysis
//--------------------------------------------------------------------
void LogMLSignal(MLSignal &signal)
{
   if(!DebugMLPredictor)
      return;
   
   Print("===== ML SIGNAL ANALYSIS =====");
   Print("Signal: ", (signal.Signal == 1 ? "BUY" : 
                     (signal.Signal == -1 ? "SELL" : "HOLD")));
   Print("Confidence: ", DoubleToString(signal.Confidence, 3), 
         " (", GetConfidenceLevelText(signal.Confidence), ")");
   Print("Buy Probability: ", DoubleToString(signal.BuyProbability, 3));
   Print("Sell Probability: ", DoubleToString(signal.SellProbability, 3));
   Print("Raw Score: ", DoubleToString(signal.Score, 4));
   Print("Model: ", signal.Model);
   Print("Timestamp: ", TimeToString(signal.Timestamp));
   Print("Valid: ", (signal.IsValid ? "YES" : "NO"));
   if(!signal.IsValid)
      Print("Error: ", signal.ValidationError);
   Print("===============================");
}

//--------------------------------------------------------------------
// Log ML Performance (Win Rate on ML Signals)
//--------------------------------------------------------------------
void LogMLPerformance()
{
   int mlSignalTrades = 0;
   int mlWins = 0;
   double mlProfit = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      // Check if order comment indicates ML signal
      if(StringFind(OrderComment(), "ML") >= 0)
      {
         mlSignalTrades++;
         if(OrderProfit() > 0)
            mlWins++;
         mlProfit += OrderProfit();
      }
   }
   
   if(mlSignalTrades > 0)
   {
      Print("===== ML PERFORMANCE =====");
      Print("Total ML Trades: ", mlSignalTrades);
      Print("ML Wins: ", mlWins);
      Print("ML Win Rate: ", DoubleToString(
         (double)mlWins / mlSignalTrades * 100, 1), "%");
      Print("ML Total Profit: $", DoubleToString(mlProfit, 2));
      Print("===========================");
   }
}

//====================================================================
// PYTHON INTEGRATION HELPERS
//====================================================================

//--------------------------------------------------------------------
// Check If Python Files Exist (For Debugging)
//--------------------------------------------------------------------
bool CheckPythonFilesExist()
{
   int h;
   bool allExist = true;
   
   h = FileOpen(SIGNAL_FILE_PATH, FILE_READ | FILE_TXT);
   if(h == INVALID_HANDLE)
   {
      Print("Missing: ", SIGNAL_FILE_PATH);
      allExist = false;
   }
   else FileClose(h);
   
   h = FileOpen(CONFIDENCE_FILE_PATH, FILE_READ | FILE_TXT);
   if(h == INVALID_HANDLE)
   {
      Print("Missing: ", CONFIDENCE_FILE_PATH);
      allExist = false;
   }
   else FileClose(h);
   
   return allExist;
}

//--------------------------------------------------------------------
// Initialize ML System
//--------------------------------------------------------------------
void InitializeMLSystem()
{
   Print("Initializing ML Predictor System...");
   
   if(!CheckPythonFilesExist())
   {
      Print("⚠️ WARNING: Some Python ML files not found yet");
      Print("   Make sure Python script is running and writing files");
   }
   
   // Try first read to populate cache
   RefreshMLSignalCache();
   
   Print("✓ ML System Initialized");
}

#endif // __MLPREDICTOR_MQH__
