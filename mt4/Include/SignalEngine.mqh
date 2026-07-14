//+------------------------------------------------------------------+
//| SignalEngine.mqh                                                 |
//| GoldPilotAI Enterprise v3.0 - Signal Fusion Layer                |
//| Unified signal generation combining technical + ML + confidence  |
//+------------------------------------------------------------------+
#ifndef __SIGNALENGINE_MQH__
#define __SIGNALENGINE_MQH__

#include "Config.mqh"
#include "Globals.mqh"
#include "EntryLogic.mqh"
#include "MLPredictor.mqh"
#include "ConfidenceScore.mqh"

//====================================================================
// SIGNAL OUTPUT STRUCTURE
//====================================================================
struct SignalOutput
{
   int Signal;                    // 1=BUY, -1=SELL, 0=HOLD
   double Confidence;            // 0.0-1.0 (combined confidence)
   double TechnicalStrength;     // 0.0-1.0 (technical signal quality)
   double MLStrength;            // 0.0-1.0 (ML signal quality)
   string Source;                // "TECHNICAL", "ML", "CONFLUENCE", "HOLD"
   string Reason;                // Why was this decision made?
   datetime Timestamp;           // When was signal generated?
   bool IsValid;                 // Passes all validation checks?
};

//====================================================================
// SIGNAL SOURCE CONSTANTS
//====================================================================
#define SOURCE_TECHNICAL   "TECHNICAL"
#define SOURCE_ML          "ML"
#define SOURCE_CONFLUENCE  "CONFLUENCE"
#define SOURCE_HOLD        "HOLD"

//====================================================================
// SIGNAL STRENGTH EVALUATION
//====================================================================

//--------------------------------------------------------------------
// Evaluate Technical Signal Strength (0.0-1.0)
//--------------------------------------------------------------------
double EvaluateTechnicalStrength(int technicalSignal)
{
   // If no technical signal, strength is zero
   if(technicalSignal == 0)
      return 0.0;
   
   // Technical signal exists, return confidence from ConfidenceScore
   ConfidenceComponent conf;
   
   if(technicalSignal == SIGNAL_BUY)
   {
      conf = CalculateConfidenceComponentsBuy();
   }
   else if(technicalSignal == SIGNAL_SELL)
   {
      conf = CalculateConfidenceComponentsSell();
   }
   else
   {
      return 0.0;
   }
   
   // Use weighted technical confidence
   return GetWeightedTechnicalConfidence(conf, (technicalSignal == SIGNAL_BUY));
}

//--------------------------------------------------------------------
// Evaluate ML Signal Strength (0.0-1.0)
//--------------------------------------------------------------------
double EvaluateMLStrength(MLSignal &mlSignal)
{
   // If ML signal is HOLD, strength is zero
   if(mlSignal.Signal == 0)
      return 0.0;
   
   // ML signal exists, return its confidence
   if(!mlSignal.IsValid)
      return 0.0;
   
   return mlSignal.Confidence;
}

//====================================================================
// SIGNAL AGREEMENT DETECTION
//====================================================================

//--------------------------------------------------------------------
// Check if Signals Agree
//--------------------------------------------------------------------
bool SignalsAgree(int technicalSignal, int mlSignal)
{
   // Both BUY
   if(technicalSignal == SIGNAL_BUY && mlSignal == SIGNAL_BUY)
      return true;
   
   // Both SELL
   if(technicalSignal == SIGNAL_SELL && mlSignal == SIGNAL_SELL)
      return true;
   
   // Both HOLD
   if(technicalSignal == SIGNAL_HOLD && mlSignal == SIGNAL_HOLD)
      return true;
   
   return false;
}

//--------------------------------------------------------------------
// Check for Signal Conflict
//--------------------------------------------------------------------
bool SignalsConflict(int technicalSignal, int mlSignal)
{
   // BUY vs SELL conflict
   if((technicalSignal == SIGNAL_BUY && mlSignal == SIGNAL_SELL) ||
      (technicalSignal == SIGNAL_SELL && mlSignal == SIGNAL_BUY))
      return true;
   
   return false;
}

//--------------------------------------------------------------------
// Get Agreement Level (0.0-1.0)
//--------------------------------------------------------------------
double GetAgreementLevel(int technicalSignal, int mlSignal, 
                        double techStrength, double mlStrength)
{
   // Perfect agreement: both same direction + both high confidence
   if(SignalsAgree(technicalSignal, mlSignal))
   {
      return (techStrength + mlStrength) / 2.0;
   }
   
   // Conflict
   if(SignalsConflict(technicalSignal, mlSignal))
   {
      return 0.0;
   }
   
   // One signal exists, other is HOLD
   if(technicalSignal != 0 && mlSignal == 0)
      return techStrength * 0.8;  // 80% (technical only)
   
   if(technicalSignal == 0 && mlSignal != 0)
      return mlStrength * 0.7;    // 70% (ML only)
   
   // Both HOLD
   return 0.0;
}

//====================================================================
// SIGNAL COMBINATION STRATEGIES
//====================================================================

//--------------------------------------------------------------------
// Conservative Strategy: Require Both Agreement + High Confidence
//--------------------------------------------------------------------
SignalOutput CombineSignalsConservative(int technicalSignal, 
                                       MLSignal &mlSignal,
                                       double techStrength,
                                       double mlStrength)
{
   SignalOutput output;
   output.Timestamp = TimeCurrent();
   
   // Check for conflicts first
   if(SignalsConflict(technicalSignal, mlSignal))
   {
      output.Signal = SIGNAL_HOLD;
      output.Confidence = 0.0;
      output.Source = SOURCE_HOLD;
      output.Reason = "CONFLICT: Technical and ML signals disagree";
      output.IsValid = false;
      return output;
   }
   
   // Both must agree and both must exceed minimum confidence
   if(SignalsAgree(technicalSignal, mlSignal))
   {
      double agreementLevel = GetAgreementLevel(technicalSignal, mlSignal,
                                                techStrength, mlStrength);
      
      if(agreementLevel >= ConservativeConfidenceThreshold)
      {
         output.Signal = technicalSignal;
         output.Confidence = agreementLevel;
         output.TechnicalStrength = techStrength;
         output.MLStrength = mlStrength;
         output.Source = SOURCE_CONFLUENCE;
         output.Reason = "CONFLUENCE: Technical + ML agree (Conservative)";
         output.IsValid = true;
         return output;
      }
   }
   
   // Default to HOLD if not confident enough
   output.Signal = SIGNAL_HOLD;
   output.Confidence = 0.0;
   output.Source = SOURCE_HOLD;
   output.Reason = "Insufficient agreement for conservative strategy";
   output.IsValid = false;
   return output;
}

//--------------------------------------------------------------------
// Balanced Strategy: Both Signals Good, Allow Slight Disagreement
//--------------------------------------------------------------------
SignalOutput CombineSignalsBalanced(int technicalSignal,
                                   MLSignal &mlSignal,
                                   double techStrength,
                                   double mlStrength)
{
   SignalOutput output;
   output.Timestamp = TimeCurrent();
   
   // Hard conflict = HOLD
   if(SignalsConflict(technicalSignal, mlSignal))
   {
      output.Signal = SIGNAL_HOLD;
      output.Confidence = 0.0;
      output.Source = SOURCE_HOLD;
      output.Reason = "CONFLICT: Hard disagreement between signals";
      output.IsValid = false;
      return output;
   }
   
   // If signals agree
   if(SignalsAgree(technicalSignal, mlSignal))
   {
      double agreementLevel = GetAgreementLevel(technicalSignal, mlSignal,
                                                techStrength, mlStrength);
      
      if(agreementLevel >= BalancedConfidenceThreshold)
      {
         output.Signal = technicalSignal;
         output.Confidence = agreementLevel;
         output.TechnicalStrength = techStrength;
         output.MLStrength = mlStrength;
         output.Source = SOURCE_CONFLUENCE;
         output.Reason = "CONFLUENCE: Strong agreement (Balanced)";
         output.IsValid = true;
         return output;
      }
   }
   
   // One signal strong enough (alone)
   if(technicalSignal != 0 && techStrength >= BalancedConfidenceThreshold)
   {
      // Check ML doesn't conflict
      if(mlSignal.Signal != -technicalSignal)
      {
         output.Signal = technicalSignal;
         output.Confidence = techStrength;
         output.TechnicalStrength = techStrength;
         output.MLStrength = mlStrength;
         output.Source = SOURCE_TECHNICAL;
         output.Reason = "TECHNICAL: Strong signal (ML not conflicting)";
         output.IsValid = true;
         return output;
      }
   }
   
   if(mlSignal.Signal != 0 && mlStrength >= BalancedConfidenceThreshold)
   {
      // Check technical doesn't conflict
      if(technicalSignal != -mlSignal.Signal)
      {
         output.Signal = mlSignal.Signal;
         output.Confidence = mlStrength;
         output.TechnicalStrength = techStrength;
         output.MLStrength = mlStrength;
         output.Source = SOURCE_ML;
         output.Reason = "ML: Strong signal (Technical not conflicting)";
         output.IsValid = true;
         return output;
      }
   }
   
   // Not enough confidence
   output.Signal = SIGNAL_HOLD;
   output.Confidence = 0.0;
   output.Source = SOURCE_HOLD;
   output.Reason = "Insufficient confidence (Balanced strategy)";
   output.IsValid = false;
   return output;
}

//--------------------------------------------------------------------
// Aggressive Strategy: Trust Strongest Signal
//--------------------------------------------------------------------
SignalOutput CombineSignalsAggressive(int technicalSignal,
                                     MLSignal &mlSignal,
                                     double techStrength,
                                     double mlStrength)
{
   SignalOutput output;
   output.Timestamp = TimeCurrent();
   
   // Hard conflict at high confidence = HOLD
   if(SignalsConflict(technicalSignal, mlSignal))
   {
      if(techStrength >= 0.75 && mlStrength >= 0.75)
      {
         output.Signal = SIGNAL_HOLD;
         output.Confidence = 0.0;
         output.Source = SOURCE_HOLD;
         output.Reason = "CONFLICT: Both sides high confidence";
         output.IsValid = false;
         return output;
      }
   }
   
   // Use strongest signal
   if(techStrength > mlStrength && technicalSignal != 0)
   {
      if(techStrength >= AggressiveConfidenceThreshold)
      {
         output.Signal = technicalSignal;
         output.Confidence = techStrength;
         output.TechnicalStrength = techStrength;
         output.MLStrength = mlStrength;
         output.Source = SOURCE_TECHNICAL;
         output.Reason = "TECHNICAL: Strongest signal (Aggressive)";
         output.IsValid = true;
         return output;
      }
   }
   
   if(mlStrength > techStrength && mlSignal.Signal != 0)
   {
      if(mlStrength >= AggressiveConfidenceThreshold)
      {
         output.Signal = mlSignal.Signal;
         output.Confidence = mlStrength;
         output.TechnicalStrength = techStrength;
         output.MLStrength = mlStrength;
         output.Source = SOURCE_ML;
         output.Reason = "ML: Strongest signal (Aggressive)";
         output.IsValid = true;
         return output;
      }
   }
   
   // Either technical or ML alone passes threshold
   if(technicalSignal != 0 && techStrength >= AggressiveConfidenceThreshold)
   {
      output.Signal = technicalSignal;
      output.Confidence = techStrength;
      output.TechnicalStrength = techStrength;
      output.MLStrength = mlStrength;
      output.Source = SOURCE_TECHNICAL;
      output.Reason = "TECHNICAL: Solo signal (Aggressive)";
      output.IsValid = true;
      return output;
   }
   
   if(mlSignal.Signal != 0 && mlStrength >= AggressiveConfidenceThreshold)
   {
      output.Signal = mlSignal.Signal;
      output.Confidence = mlStrength;
      output.TechnicalStrength = techStrength;
      output.MLStrength = mlStrength;
      output.Source = SOURCE_ML;
      output.Reason = "ML: Solo signal (Aggressive)";
      output.IsValid = true;
      return output;
   }
   
   // Not enough confidence
   output.Signal = SIGNAL_HOLD;
   output.Confidence = 0.0;
   output.Source = SOURCE_HOLD;
   output.Reason = "Insufficient confidence (Aggressive strategy)";
   output.IsValid = false;
   return output;
}

//====================================================================
// CONFIG VARIABLE VALIDATION
//====================================================================

//--------------------------------------------------------------------
// Get Confidence Thresholds Based on Mode
//--------------------------------------------------------------------
void GetConfidenceThresholds(double &conservative, double &balanced, 
                             double &aggressive)
{
   conservative = ConservativeConfidenceThreshold;
   balanced = BalancedConfidenceThreshold;
   aggressive = AggressiveConfidenceThreshold;
}

//====================================================================
// MASTER SIGNAL ENGINE
//====================================================================

//--------------------------------------------------------------------
// Generate Final Trading Signal (MASTER FUNCTION)
//--------------------------------------------------------------------
SignalOutput GenerateFinalSignal()
{
   SignalOutput output;
   
   // Step 1: Generate technical signal
   int technicalSignal = GenerateEntrySignal();
   
   // Step 2: Get ML signal (cached for efficiency)
   MLSignal mlSignal = GetMLSignalCached();
   
   // Step 3: Evaluate signal strengths
   double techStrength = EvaluateTechnicalStrength(technicalSignal);
   double mlStrength = EvaluateMLStrength(mlSignal);
   
   // Step 4: Combine signals based on strategy mode
   if(SignalStrategy == STRATEGY_CONSERVATIVE)
   {
      output = CombineSignalsConservative(technicalSignal, mlSignal,
                                         techStrength, mlStrength);
   }
   else if(SignalStrategy == STRATEGY_BALANCED)
   {
      output = CombineSignalsBalanced(technicalSignal, mlSignal,
                                      techStrength, mlStrength);
   }
   else if(SignalStrategy == STRATEGY_AGGRESSIVE)
   {
      output = CombineSignalsAggressive(technicalSignal, mlSignal,
                                        techStrength, mlStrength);
   }
   else
   {
      // Default to balanced
      output = CombineSignalsBalanced(technicalSignal, mlSignal,
                                      techStrength, mlStrength);
   }
   
   // Step 5: Apply final confidence filter
   if(output.Signal != 0 && output.Confidence < MinConfidenceRequired)
   {
      output.Signal = SIGNAL_HOLD;
      output.Source = SOURCE_HOLD;
      output.Reason += " [FILTERED: Below minimum confidence]";
      output.IsValid = false;
   }
   
   // Step 6: Log if debugging
   LogSignalGeneration(output, technicalSignal, mlSignal, 
                      techStrength, mlStrength);
   
   return output;
}

//====================================================================
// SIGNAL ANALYSIS & REPORTING
//====================================================================

//--------------------------------------------------------------------
// Log Signal Generation Details
//--------------------------------------------------------------------
void LogSignalGeneration(SignalOutput &output, int techSignal, 
                        MLSignal &mlSignal, double techStrength,
                        double mlStrength)
{
   if(!DebugSignalEngine)
      return;
   
   Print("===== SIGNAL ENGINE ANALYSIS =====");
   Print("Time: ", TimeToString(output.Timestamp));
   Print("");
   Print("Input Signals:");
   Print("  Technical: ", (techSignal == 1 ? "BUY" : (techSignal == -1 ? "SELL" : "HOLD")),
         " (Strength: ", DoubleToString(techStrength, 2), ")");
   Print("  ML:        ", (mlSignal.Signal == 1 ? "BUY" : (mlSignal.Signal == -1 ? "SELL" : "HOLD")),
         " (Strength: ", DoubleToString(mlStrength, 2), 
         ", Valid: ", (mlSignal.IsValid ? "Yes" : "No"), ")");
   Print("");
   Print("Output Signal:");
   Print("  Signal:     ", (output.Signal == 1 ? "BUY" : (output.Signal == -1 ? "SELL" : "HOLD")));
   Print("  Confidence: ", DoubleToString(output.Confidence, 2));
   Print("  Source:     ", output.Source);
   Print("  Valid:      ", (output.IsValid ? "Yes" : "No"));
   Print("  Reason:     ", output.Reason);
   Print("====================================");
}

//--------------------------------------------------------------------
// Get Signal Summary String
//--------------------------------------------------------------------
string GetSignalSummary(SignalOutput &output)
{
   string signal = (output.Signal == 1 ? "BUY" : 
                   (output.Signal == -1 ? "SELL" : "HOLD"));
   
   return signal + " | " + output.Source + 
          " | Conf:" + DoubleToString(output.Confidence, 2) +
          " | " + output.Reason;
}

//--------------------------------------------------------------------
// Get Signal Comment for Chart
//--------------------------------------------------------------------
string GetSignalComment(SignalOutput &output)
{
   return (output.Signal == 1 ? "BUY " : 
          (output.Signal == -1 ? "SELL " : "HOLD ")) +
         DoubleToString(output.Confidence * 100, 0) + "% " +
         output.Source;
}

//====================================================================
// SIGNAL STATISTICS
//====================================================================

//--------------------------------------------------------------------
// Track Signal Statistics
//--------------------------------------------------------------------
void UpdateSignalStatistics(SignalOutput &output)
{
   // Update global tracking
   if(output.Signal == SIGNAL_BUY)
   {
      LastSignal = SIGNAL_BUY;
   }
   else if(output.Signal == SIGNAL_SELL)
   {
      LastSignal = SIGNAL_SELL;
   }
   
   // Could extend with more stats (win rate by source, etc.)
}

//====================================================================
// SIGNAL VALIDATION
//====================================================================

//--------------------------------------------------------------------
// Validate Signal Before Execution
//--------------------------------------------------------------------
bool IsSignalValid(SignalOutput &output)
{
   return output.IsValid && output.Signal != SIGNAL_HOLD;
}

//--------------------------------------------------------------------
// Get Signal Strength (0.0-1.0)
//--------------------------------------------------------------------
double GetSignalStrength(SignalOutput &output)
{
   return output.Confidence;
}

//--------------------------------------------------------------------
// Get Signal Source Description
//--------------------------------------------------------------------
string GetSignalSourceDescription(SignalOutput &output)
{
   if(output.Source == SOURCE_CONFLUENCE)
      return "Both Technical & ML agree";
   else if(output.Source == SOURCE_TECHNICAL)
      return "Technical analysis signal";
   else if(output.Source == SOURCE_ML)
      return "AI/ML model signal";
   else
      return "No valid signal";
}

#endif // __SIGNALENGINE_MQH__
