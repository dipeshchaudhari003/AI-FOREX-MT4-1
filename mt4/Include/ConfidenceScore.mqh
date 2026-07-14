//+------------------------------------------------------------------+
//| ConfidenceScore.mqh                                              |
//| GoldPilotAI Enterprise v3.0 - AI Layer                           |
//| Multi-factor confidence calculation & weighting                  |
//+------------------------------------------------------------------+
#ifndef __CONFIDENCESCORE_MQH__
#define __CONFIDENCESCORE_MQH__

#include "Config.mqh"
#include "Globals.mqh"
#include "Indicators.mqh"
#include "MLPredictor.mqh"

//====================================================================
// CONFIDENCE COMPONENT STRUCTURE
//====================================================================
struct ConfidenceComponent
{
   double EMAConfidence;          // EMA alignment strength
   double ATRConfidence;          // Volatility confidence
   double ADXConfidence;          // Trend strength confidence
   double BollingerConfidence;    // Bollinger band setup confidence
   double RSIConfidence;          // RSI extreme level confidence
   double StochasticConfidence;   // Stochastic momentum confidence
   double TechnicalAverage;       // Average of all technical
   double MLConfidence;           // ML model confidence (0-1)
   double CombinedConfidence;     // Final weighted confidence (0-1)
};

//====================================================================
// TECHNICAL INDICATOR CONFIDENCE CALCULATIONS
//====================================================================

//--------------------------------------------------------------------
// EMA Alignment Confidence (How well aligned are the EMAs?)
//--------------------------------------------------------------------
double CalculateEMAConfidenceBuy()
{
   // Perfect setup: EMA9 > EMA20 > EMA50 > EMA200
   // Confidence increases with each confirmed alignment
   
   double confidence = 0.0;
   
   if(EMA9 > EMA20) confidence += 0.25;
   if(EMA20 > EMA50) confidence += 0.25;
   if(EMA50 > EMA200) confidence += 0.25;
   if(EMA9 > EMA200) confidence += 0.25;  // Long term alignment
   
   // Cap at 1.0
   return MathMin(confidence, 1.0);
}

double CalculateEMAConfidenceSell()
{
   // Perfect setup: EMA9 < EMA20 < EMA50 < EMA200
   
   double confidence = 0.0;
   
   if(EMA9 < EMA20) confidence += 0.25;
   if(EMA20 < EMA50) confidence += 0.25;
   if(EMA50 < EMA200) confidence += 0.25;
   if(EMA9 < EMA200) confidence += 0.25;
   
   return MathMin(confidence, 1.0);
}

//--------------------------------------------------------------------
// ATR Confidence (Is volatility in optimal range?)
//--------------------------------------------------------------------
double CalculateATRConfidence()
{
   // ATR too low = no movement, too high = risk
   // Optimal zone is middle
   
   if(ATR < ATRMinimum)
      return 0.3;  // Low confidence - insufficient volatility
   
   if(ATR > ATRMaximum)
      return 0.4;  // Low confidence - excessive volatility
   
   // Calculate confidence as inverse of deviation from middle
   double midpoint = (ATRMinimum + ATRMaximum) / 2.0;
   double deviation = MathAbs(ATR - midpoint);
   double maxDeviation = midpoint;
   
   double confidence = 1.0 - (deviation / maxDeviation);
   
   return MathMax(MathMin(confidence, 1.0), 0.3);
}

//--------------------------------------------------------------------
// ADX Confidence (How strong is the trend?)
//--------------------------------------------------------------------
double CalculateADXConfidence()
{
   // ADX < 20: Weak trend (low confidence)
   // ADX 20-40: Strong trend (high confidence)
   // ADX > 40: Very strong trend (may be overextended)
   
   if(ADX < 20)
      return 0.3;
   
   if(ADX >= 20 && ADX <= 40)
      return 0.5 + ((ADX - 20) / 20.0) * 0.5;  // Scale 0.5 to 1.0
   
   if(ADX > 40)
      return 0.8;  // Good but watch for exhaustion
   
   return 0.5;
}

//--------------------------------------------------------------------
// Bollinger Band Confidence (Setup quality)
//--------------------------------------------------------------------
double CalculateBollingerConfidenceBuy()
{
   // Best: Price near lower band with room to move up
   // Confidence decreases as price moves to middle/upper band
   
   double bandRange = BBUpper - BBLower;
   
   if(bandRange <= 0)
      return 0.5;
   
   // Distance from lower band (0 = at lower, 1 = at upper)
   double distanceFromLower = (CurrClose - BBLower) / bandRange;
   
   // Optimal: Price in lower 30% of band
   if(distanceFromLower <= 0.3)
      return 0.9;
   
   if(distanceFromLower <= 0.5)
      return 0.7;
   
   if(distanceFromLower <= 0.7)
      return 0.5;
   
   return 0.3;  // Price too high, weak setup
}

double CalculateBollingerConfidenceSell()
{
   // Best: Price near upper band with room to move down
   
   double bandRange = BBUpper - BBLower;
   
   if(bandRange <= 0)
      return 0.5;
   
   // Distance from upper band (0 = at upper, 1 = at lower)
   double distanceFromUpper = (BBUpper - CurrClose) / bandRange;
   
   // Optimal: Price in upper 30% of band
   if(distanceFromUpper <= 0.3)
      return 0.9;
   
   if(distanceFromUpper <= 0.5)
      return 0.7;
   
   if(distanceFromUpper <= 0.7)
      return 0.5;
   
   return 0.3;
}

//--------------------------------------------------------------------
// RSI Confidence (Is RSI in extreme territory?)
//--------------------------------------------------------------------
double CalculateRSIConfidenceBuy()
{
   // Best: RSI in oversold (below 30) and recovering
   // Confidence decreases as RSI approaches neutral (50)
   
   if(RSI < 30)
      return 0.9;
   
   if(RSI < 40)
      return 0.7;
   
   if(RSI < 50)
      return 0.5;
   
   if(RSI < 60)
      return 0.3;
   
   return 0.1;  // RSI overbought, poor buy setup
}

double CalculateRSIConfidenceSell()
{
   // Best: RSI in overbought (above 70)
   
   if(RSI > 70)
      return 0.9;
   
   if(RSI > 60)
      return 0.7;
   
   if(RSI > 50)
      return 0.5;
   
   if(RSI > 40)
      return 0.3;
   
   return 0.1;  // RSI oversold, poor sell setup
}

//--------------------------------------------------------------------
// Stochastic Confidence (Momentum alignment)
//--------------------------------------------------------------------
double CalculateStochasticConfidenceBuy()
{
   // Best: Stochastic in oversold and Main > Signal
   
   if(StochMain < 20 && StochMain > StochSignal)
      return 0.9;
   
   if(StochMain < 30 && StochMain > StochSignal)
      return 0.8;
   
   if(StochMain < 50 && StochMain > StochSignal)
      return 0.6;
   
   if(StochMain > StochSignal)
      return 0.4;
   
   return 0.1;  // Main below signal, poor momentum
}

double CalculateStochasticConfidenceSell()
{
   // Best: Stochastic in overbought and Main < Signal
   
   if(StochMain > 80 && StochMain < StochSignal)
      return 0.9;
   
   if(StochMain > 70 && StochMain < StochSignal)
      return 0.8;
   
   if(StochMain > 50 && StochMain < StochSignal)
      return 0.6;
   
   if(StochMain < StochSignal)
      return 0.4;
   
   return 0.1;  // Main above signal, poor momentum
}

//====================================================================
// MULTI-FACTOR CONFIDENCE CALCULATION
//====================================================================

//--------------------------------------------------------------------
// Calculate All Technical Confidence Components (BUY)
//--------------------------------------------------------------------
ConfidenceComponent CalculateConfidenceComponentsBuy()
{
   ConfidenceComponent conf;
   
   conf.EMAConfidence = CalculateEMAConfidenceBuy();
   conf.ATRConfidence = CalculateATRConfidence();
   conf.ADXConfidence = CalculateADXConfidence();
   conf.BollingerConfidence = CalculateBollingerConfidenceBuy();
   conf.RSIConfidence = CalculateRSIConfidenceBuy();
   conf.StochasticConfidence = CalculateStochasticConfidenceBuy();
   
   // Simple average of technical indicators
   conf.TechnicalAverage = (conf.EMAConfidence + 
                            conf.ATRConfidence + 
                            conf.ADXConfidence + 
                            conf.BollingerConfidence + 
                            conf.RSIConfidence + 
                            conf.StochasticConfidence) / 6.0;
   
   return conf;
}

//--------------------------------------------------------------------
// Calculate All Technical Confidence Components (SELL)
//--------------------------------------------------------------------
ConfidenceComponent CalculateConfidenceComponentsSell()
{
   ConfidenceComponent conf;
   
   conf.EMAConfidence = CalculateEMAConfidenceSell();
   conf.ATRConfidence = CalculateATRConfidence();
   conf.ADXConfidence = CalculateADXConfidence();
   conf.BollingerConfidence = CalculateBollingerConfidenceSell();
   conf.RSIConfidence = CalculateRSIConfidenceSell();
   conf.StochasticConfidence = CalculateStochasticConfidenceSell();
   
   // Simple average of technical indicators
   conf.TechnicalAverage = (conf.EMAConfidence + 
                            conf.ATRConfidence + 
                            conf.ADXConfidence + 
                            conf.BollingerConfidence + 
                            conf.RSIConfidence + 
                            conf.StochasticConfidence) / 6.0;
   
   return conf;
}

//--------------------------------------------------------------------
// Calculate Combined Confidence (Technical + ML)
//--------------------------------------------------------------------
ConfidenceComponent CalculateCombinedConfidence(
   ConfidenceComponent &technicalConf, 
   double mlConfidence)
{
   ConfidenceComponent combined;
   
   combined.TechnicalAverage = technicalConf.TechnicalAverage;
   combined.MLConfidence = mlConfidence;
   
   // Weighted combination
   // 60% technical, 40% ML (adjust as needed)
   combined.CombinedConfidence = (technicalConf.TechnicalAverage * 0.6) + 
                              (mlConfidence * 0.4);
   
   // Ensure within bounds
   combined.CombinedConfidence = MathMax(0.0, 
                                      MathMin(1.0, 
                                              combined.CombinedConfidence));
   
   // Copy component scores
   combined.EMAConfidence = technicalConf.EMAConfidence;
   combined.ATRConfidence = technicalConf.ATRConfidence;
   combined.ADXConfidence = technicalConf.ADXConfidence;
   combined.BollingerConfidence = technicalConf.BollingerConfidence;
   combined.RSIConfidence = technicalConf.RSIConfidence;
   combined.StochasticConfidence = technicalConf.StochasticConfidence;
   
   return combined;
}

//====================================================================
// DYNAMIC CONFIDENCE WEIGHTING
//====================================================================

//--------------------------------------------------------------------
// Get Weighted Technical Confidence (Emphasize Strong Signals)
//--------------------------------------------------------------------
double GetWeightedTechnicalConfidence(ConfidenceComponent &conf, 
                                      bool isBuy)
{
   // Weight the components by importance
   double weighted = 0.0;
   double totalWeight = 0.0;
   
   // EMA alignment is most important
   weighted += conf.EMAConfidence * 0.30;
   totalWeight += 0.30;
   
   // ADX trend strength
   weighted += conf.ADXConfidence * 0.25;
   totalWeight += 0.25;
   
   // Bollinger band setup
   weighted += conf.BollingerConfidence * 0.20;
   totalWeight += 0.20;
   
   // RSI + Stochastic momentum (equal weight)
   weighted += conf.RSIConfidence * 0.125;
   weighted += conf.StochasticConfidence * 0.125;
   totalWeight += 0.25;
   
   // ATR volatility context
   weighted += conf.ATRConfidence * 0.10;
   totalWeight += 0.10;
   
   return weighted / totalWeight;
}

//--------------------------------------------------------------------
// Apply Confidence Filter
//--------------------------------------------------------------------
bool PassesConfidenceFilter(double confidence, double minRequired)
{
   return (confidence >= minRequired);
}

//====================================================================
// CONFIDENCE-BASED POSITION SIZING
//====================================================================

//--------------------------------------------------------------------
// Scale Lot Size Based on Confidence
//--------------------------------------------------------------------
double ScaleLotByConfidence(double baseLot, double confidence)
{
   // Scale lot size with confidence
   // 50% confidence = 50% of base lot
   // 100% confidence = 100% of base lot
   
   double scaledLot = baseLot * confidence;
   
   // Ensure minimum
   if(scaledLot < MinimumLotSize)
      scaledLot = MinimumLotSize;
   
   // Ensure maximum
   if(scaledLot > MaximumLotSize)
      scaledLot = MaximumLotSize;
   
   return scaledLot;
}

//--------------------------------------------------------------------
// Get Lot Size Tier Based on Confidence
//--------------------------------------------------------------------
double GetConfidenceTierLotSize(double confidence)
{
   // Tier-based position sizing
   // Low confidence = small position
   // High confidence = full position
   
   if(confidence < 0.50)
      return MinimumLotSize;  // Minimum size
   
   if(confidence < 0.60)
      return MinimumLotSize * 2;
   
   if(confidence < 0.70)
      return LotSize * 0.5;
   
   if(confidence < 0.80)
      return LotSize * 0.75;
   
   return LotSize;  // Full size
}

//====================================================================
// CONFIDENCE ANALYSIS & REPORTING
//====================================================================

//--------------------------------------------------------------------
// Get Confidence Color (For Chart Display)
//--------------------------------------------------------------------
color GetConfidenceColor(double confidence)
{
   if(confidence >= 0.85)
      return clrDarkGreen;
   else if(confidence >= 0.70)
      return clrGreen;
   else if(confidence >= 0.55)
      return clrYellow;
   else if(confidence >= 0.40)
      return clrOrange;
   else
      return clrRed;
}

//--------------------------------------------------------------------
// Log Confidence Analysis
//--------------------------------------------------------------------
void LogConfidenceAnalysis(ConfidenceComponent &conf, bool isBuy)
{
   if(!DebugConfidenceScore)
      return;
   
   Print("===== CONFIDENCE ANALYSIS =====");
   Print("Direction: ", (isBuy ? "BUY" : "SELL"));
   Print("");
   Print("Technical Components:");
   Print("  EMA:         ", DoubleToString(conf.EMAConfidence, 2));
   Print("  ATR:         ", DoubleToString(conf.ATRConfidence, 2));
   Print("  ADX:         ", DoubleToString(conf.ADXConfidence, 2));
   Print("  Bollinger:   ", DoubleToString(conf.BollingerConfidence, 2));
   Print("  RSI:         ", DoubleToString(conf.RSIConfidence, 2));
   Print("  Stochastic:  ", DoubleToString(conf.StochasticConfidence, 2));
   Print("");
   Print("Technical Average: ", DoubleToString(conf.TechnicalAverage, 2));
   Print("ML Confidence:     ", DoubleToString(conf.MLConfidence, 2));
   Print("Combined:          ", DoubleToString(conf.CombinedConfidence, 2));
   Print("Level:             ", GetConfidenceLevelText(conf.CombinedConfidence));
   Print("================================");
}

//--------------------------------------------------------------------
// Get Confidence Summary String
//--------------------------------------------------------------------
string GetConfidenceSummary(ConfidenceComponent &conf)
{
   return "Tech:" + DoubleToString(conf.TechnicalAverage, 2) + 
          " ML:" + DoubleToString(conf.MLConfidence, 2) + 
          " Combined:" + DoubleToString(conf.CombinedConfidence, 2) +
          " (" + GetConfidenceLevelText(conf.CombinedConfidence) + ")";
}

//====================================================================
// MASTER CONFIDENCE CALCULATION
//====================================================================

//--------------------------------------------------------------------
// Calculate Final Confidence for Signal
//--------------------------------------------------------------------
double CalculateFinalConfidence(int signal, MLSignal &mlSignal)
{
   // If no signal, confidence is zero
   if(signal == 0)
      return 0.0;
   
   // Calculate technical confidence
   ConfidenceComponent technicalConf;
   
   if(signal == SIGNAL_BUY)
   {
      technicalConf = CalculateConfidenceComponentsBuy();
   }
   else if(signal == SIGNAL_SELL)
   {
      technicalConf = CalculateConfidenceComponentsSell();
   }
   else
   {
      return 0.0;
   }
   
   // Get ML confidence (from cached signal)
   double mlConf = mlSignal.Confidence;
   
   // Combine technical and ML
   ConfidenceComponent finalConf = CalculateCombinedConfidence(
      technicalConf, mlConf);
   
   // Log for debugging
   LogConfidenceAnalysis(finalConf, (signal == SIGNAL_BUY));
   
   // Return combined confidence
   return finalConf.CombinedConfidence;
}

#endif // __CONFIDENCESCORE_MQH__
