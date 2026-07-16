//+------------------------------------------------------------------+
//| RiskManager.mqh                                                  |
//| GoldPilotAI Enterprise v3.0 - Strategy Layer                     |
//| Trade-level risk management and position sizing                  |
//+------------------------------------------------------------------+
#ifndef __RISKMANAGER_MQH__
#define __RISKMANAGER_MQH__

#include "Config.mqh"
#include "Globals.mqh"
#include "TradeManager.mqh"
#include "MoneyManagement.mqh"

//====================================================================
// RISK CALCULATION STRUCTURE
//====================================================================
struct TradeRisk
{
   double EntryPrice;
   double StopLoss;
   double TakeProfit;
   double RiskInPoints;
   double RewardInPoints;
   double RiskInDollars;
   double RewardInDollars;
   double LotSize;
   double RiskRewardRatio;
   bool IsValid;
   string ValidationError;
};

//====================================================================
// RISK CALCULATION FUNCTIONS
//====================================================================

//--------------------------------------------------------------------
// Calculate Risk in Points (Entry to SL)
//--------------------------------------------------------------------
double CalculateRiskPoints(double entry, double stopLoss)
{
   return MathAbs(entry - stopLoss) / Point;
}

//--------------------------------------------------------------------
// Calculate Reward in Points (Entry to TP)
//--------------------------------------------------------------------
double CalculateRewardPoints(double entry, double takeProfit)
{
   return MathAbs(takeProfit - entry) / Point;
}

//--------------------------------------------------------------------
// Calculate Risk in Dollars
//--------------------------------------------------------------------
double CalculateRiskDollars(double lot, double riskPoints)
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

   Print("P_TickValue = ", tickValue);
   Print("P_TickSize  = ", tickSize);

   double risk = lot * riskPoints * Point / tickSize * tickValue;

   Print("P_Calculated Risk = ", risk);

   return risk;
}

//--------------------------------------------------------------------
// Calculate Reward in Dollars
//--------------------------------------------------------------------
double CalculateRewardDollars(double lot, double rewardPoints)
{
   double pipValue = 0.01;  // For XAUUSD
   return lot * 100000 * pipValue * rewardPoints / 100;
}

//--------------------------------------------------------------------
// Calculate Risk/Reward Ratio
//--------------------------------------------------------------------
double CalculateRiskRewardRatio(double riskPoints, double rewardPoints)
{
   if(riskPoints <= 0)
      return 0;
   
   return rewardPoints / riskPoints;
}

//====================================================================
// POSITION SIZING STRATEGIES
//====================================================================

//--------------------------------------------------------------------
// Fixed Lot Size Strategy
//--------------------------------------------------------------------
double GetLotSizeFixed()
{
   return GetFixedLotSize();
}

//--------------------------------------------------------------------
// Risk-Based Lot Size (Recommended)
//--------------------------------------------------------------------
double GetLotSizeRiskBased(double riskPercent, double riskPoints)
{
   Print("******** ENTERED GetLotSizeRiskBased ********");
   Print("Risk Percent = ", riskPercent);
   Print("Risk Points  = ", riskPoints);

   if(riskPoints <= 0)
      return 0;

   return CalculateLotSize(riskPercent, riskPoints);
}

//--------------------------------------------------------------------
// ATR-Based Position Sizing
//--------------------------------------------------------------------
double GetLotSizeATR(double atrMultiplier)
{
   // Use ATR for dynamic position sizing
   // Smaller position when volatility is high, larger when low
   
   double atrPoints = ATR;
   
   if(atrPoints <= 0)
      return MinimumLotSize;
   
   // Calculate SL based on ATR
   double slPoints = atrPoints * atrMultiplier;
   
   // Use fixed risk percentage
   double lot = GetLotSizeRiskBased(RiskPerTradePercent, slPoints);
   
   return lot;
}

//--------------------------------------------------------------------
// Equity-Based Position Sizing
//--------------------------------------------------------------------
double GetLotSizeEquityBased(double equityPercent, double riskPoints)
{
   double equity = AccountEquity();
   double targetRisk = (equity * equityPercent) / 100.0;
   
   double pipValue = 0.01;  // For XAUUSD
   double lot = targetRisk / (riskPoints * pipValue);
   
   lot = MathRound(lot * 100) / 100;
   
   if(lot < MinimumLotSize) lot = MinimumLotSize;
   if(lot > MaximumLotSize) lot = MaximumLotSize;
   
   return lot;
}

//====================================================================
// POSITION VALIDATION
//====================================================================

//--------------------------------------------------------------------
// Validate Trade Risk Parameters
//--------------------------------------------------------------------
TradeRisk ValidateTradeRisk(double entry, double sl, double tp, double lot)
{
   TradeRisk risk;
   risk.EntryPrice = entry;
   risk.StopLoss = sl;
   risk.TakeProfit = tp;
   risk.LotSize = lot;
   risk.IsValid = true;
   risk.ValidationError = "";
   
   //---
   // Calculate risk metrics
   //---
   risk.RiskInPoints = CalculateRiskPoints(entry, sl);
   risk.RewardInPoints = CalculateRewardPoints(entry, tp);
   risk.RiskInDollars = CalculateRiskDollars(lot, risk.RiskInPoints);
   risk.RewardInDollars = CalculateRewardDollars(lot, risk.RewardInPoints);
   risk.RiskRewardRatio = CalculateRiskRewardRatio(
      risk.RiskInPoints, risk.RewardInPoints);
   
   // ===== DEBUG =====
   Print("===== TRADE RISK =====");
   Print("Entry      = ", entry);
   Print("Stop Loss  = ", sl);
   Print("Lot Size   = ", lot);
   Print("Risk Points= ", risk.RiskInPoints);
   Print("Risk Dollar= ", risk.RiskInDollars);
   Print("======================");

   //---
   // Check: Minimum Risk
   //---
   if(risk.RiskInPoints < MinimumSLDistance)
   {
      risk.IsValid = false;
      risk.ValidationError = StringFormat(
         "Risk too small: %.0f < %.0f points",
         risk.RiskInPoints, MinimumSLDistance);
      return risk;
   }
   
   //---
   // Check: Maximum Risk Per Trade
   //---
   if(risk.RiskInDollars > MaxRiskPerTrade)
   {
      risk.IsValid = false;
      risk.ValidationError = StringFormat(
         "Risk exceeds max: $%.2f > $%.2f",
         risk.RiskInDollars, MaxRiskPerTrade);
      return risk;
   }
   
   Print("DRM===== RR CHECK =====");
   Print("DRM_Risk Points = ", risk.RiskInPoints);
   Print("DRM_Reward Points = ", risk.RewardInPoints);
   Print("DRM_Actual RR = ", risk.RiskRewardRatio);
   Print("DRM_Required RR = ", RiskRewardRatio);

   //---
   // Check: Risk/Reward Ratio
   //---
   if(RiskRewardRatio > 0)
   {
      if(risk.RiskRewardRatio < RiskRewardRatio)
      {
         risk.IsValid = false;
         risk.ValidationError = StringFormat(
            "Poor R:R: %.2f:1 < %.2f:1",
            risk.RiskRewardRatio, RiskRewardRatio);
         return risk;
      }
   }
   
   //---
   // Check: Minimum Reward
   //---
   if(risk.RewardInPoints < MinimumTPDistance)
   {
      risk.IsValid = false;
      risk.ValidationError = StringFormat(
         "Reward too small: %.0f < %.0f points",
         risk.RewardInPoints, MinimumTPDistance);
      return risk;
   }
   
   //---
   // Check: Risk/Reward Imbalance
   //---
   if(risk.RewardInPoints < risk.RiskInPoints * 0.5)  // Reward < 50% of risk
   {
      risk.IsValid = false;
      risk.ValidationError = StringFormat(
         "Reward much less than risk: %.0f < %.0f*0.5",
         risk.RewardInPoints, risk.RiskInPoints);
      return risk;
   }
   
   return risk;
}

//====================================================================
// RISK-ADJUSTED ENTRY POINTS
//====================================================================

//--------------------------------------------------------------------
// Calculate TP Based on Risk (For Fixed R:R)
//--------------------------------------------------------------------
double CalculateTPFromRisk(double entry, double sl, double rrRatio, 
                           bool isBuy)
{
   double riskPoints = CalculateRiskPoints(entry, sl);
   double rewardPoints = riskPoints * rrRatio;
   
   if(isBuy)
      return entry + (rewardPoints * Point);
   else
      return entry - (rewardPoints * Point);
}

//--------------------------------------------------------------------
// Calculate SL Based on TP (For Fixed R:R)
//--------------------------------------------------------------------
double CalculateSLFromTP(double entry, double tp, double rrRatio, 
                         bool isBuy)
{
   double rewardPoints = CalculateRewardPoints(entry, tp);
   double riskPoints = rewardPoints / rrRatio;
   
   if(isBuy)
      return entry - (riskPoints * Point);
   else
      return entry + (riskPoints * Point);
}

//====================================================================
// KELLY CRITERION (Advanced Position Sizing)
//====================================================================

//--------------------------------------------------------------------
// Kelly Criterion for Position Sizing
// Formula: f* = (WinRate × AvgWin - LoseRate × AvgLoss) / AvgWin
// Use fraction (typically 25% of Kelly for safety)
//--------------------------------------------------------------------
double CalculateKellyCriterion(double winRate, double avgWinPoints, 
                               double avgLossPoints)
{
   if(avgWinPoints <= 0)
      return 0;
   
   double winRateDecimal = winRate / 100.0;
   double loseRate = 1.0 - winRateDecimal;
   
   // Kelly formula
   double kelly = (winRateDecimal * avgWinPoints - 
                   loseRate * avgLossPoints) / avgWinPoints;
   
   // Apply safety factor (use 25% of Kelly)
   double safeKelly = kelly * 0.25;
   
   // Convert to lot size
   double equity = AccountEquity();
   double baseLot = GetPositionSizeEquityPercent(safeKelly * 100);
   
   return baseLot;
}

//--------------------------------------------------------------------
// Get Average Winning Trade Size (Points)
//--------------------------------------------------------------------
double GetAverageWinPoints()
{
   double totalWinPoints = 0;
   int winCount = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderProfit() <= 0)
         continue;
      
      // Calculate profit in points
      double profitPoints = OrderProfit() / (OrderLots() * 0.01);
      
      totalWinPoints += profitPoints;
      winCount++;
   }
   
   if(winCount == 0)
      return 0;
   
   return totalWinPoints / winCount;
}

//--------------------------------------------------------------------
// Get Average Losing Trade Size (Points)
//--------------------------------------------------------------------
double GetAverageLossPoints()
{
   double totalLossPoints = 0;
   int lossCount = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderProfit() >= 0)
         continue;
      
      // Calculate loss in points
      double lossPoints = MathAbs(OrderProfit()) / (OrderLots() * 0.01);
      
      totalLossPoints += lossPoints;
      lossCount++;
   }
   
   if(lossCount == 0)
      return 0;
   
   return totalLossPoints / lossCount;
}

//====================================================================
// RISK PER ACCOUNT EQUITY
//====================================================================

//--------------------------------------------------------------------
// Get Maximum Risk Per Single Trade
//--------------------------------------------------------------------
double GetMaxRiskPerTrade()
{
   double equity = AccountEquity();
   return (equity * MaxRiskPercent) / 100.0;
}

//--------------------------------------------------------------------
// Get Risk Remaining Today
//--------------------------------------------------------------------
double GetRiskRemainingToday()
{
   double equity = AccountEquity();
   double maxDailyRisk = (equity * MaxDailyLossPercent) / 100.0;
   double usedDailyRisk = GetDailyLoss();
   
   double remaining = maxDailyRisk - usedDailyRisk;
   return MathMax(0, remaining);
}

//====================================================================
// PRE-TRADE RISK CHECK
//====================================================================

//--------------------------------------------------------------------
// Master Pre-Trade Risk Validation
//--------------------------------------------------------------------
bool PreTradeRiskCheck(TradeRisk &tradeRisk)
{
   //---
   // Validate risk parameters
   //---
   if(!tradeRisk.IsValid)
   {
      Print("❌ TRADE BLOCKED: ", tradeRisk.ValidationError);
      return false;
   }
   
   //---
   // Check risk is within daily allowance
   //---
   if(tradeRisk.RiskInDollars > GetRiskRemainingToday())
   {
      Print("❌ TRADE BLOCKED: Risk exceeds daily allowance");
      return false;
   }
   
   //---
   // Check lot size is valid
   //---
   if(tradeRisk.LotSize < MinimumLotSize || 
      tradeRisk.LotSize > MaximumLotSize)
   {
      Print("❌ TRADE BLOCKED: Invalid lot size ", tradeRisk.LotSize);
      return false;
   }
   
   //---
   // Check margin available
   //---
   double marginRequired = tradeRisk.LotSize * 1000;  // Rough estimate
   if(AccountFreeMargin() < marginRequired)
   {
      Print("❌ TRADE BLOCKED: Insufficient margin");
      return false;
   }
   
   return true;
}

//====================================================================
// RISK REPORTING
//====================================================================

//--------------------------------------------------------------------
// Log Trade Risk Analysis
//--------------------------------------------------------------------
void LogTradeRisk(TradeRisk &risk)
{
   if(!DebugRiskManager)
      return;
   
   Print("===== TRADE RISK ANALYSIS =====");
   Print("Entry: ", risk.EntryPrice);
   Print("SL: ", risk.StopLoss, " (Risk: ", risk.RiskInPoints, "pts)");
   Print("TP: ", risk.TakeProfit, " (Reward: ", risk.RewardInPoints, "pts)");
   Print("R:R Ratio: ", DoubleToString(risk.RiskRewardRatio, 2), ":1");
   Print("Lot Size: ", DoubleToString(risk.LotSize, 2));
   Print("Risk $: ", DoubleToString(risk.RiskInDollars, 2));
   Print("Reward $: ", DoubleToString(risk.RewardInDollars, 2));
   Print("Status: ", (risk.IsValid ? "✓ VALID" : "✗ INVALID"));
   if(!risk.IsValid)
      Print("Error: ", risk.ValidationError);
   Print("================================");
}

//====================================================================
// RISK SUMMARY FOR DECISION MAKING
//====================================================================

//--------------------------------------------------------------------
// Get Risk Summary String
//--------------------------------------------------------------------
string GetRiskSummary(TradeRisk &risk)
{
   string summary = "";
   
   summary += "Risk: " + DoubleToString(risk.RiskInDollars, 2) + "$ | ";
   summary += "Reward: " + DoubleToString(risk.RewardInDollars, 2) + "$ | ";
   summary += "R:R: " + DoubleToString(risk.RiskRewardRatio, 2) + ":1 | ";
   summary += "Lot: " + DoubleToString(risk.LotSize, 2);
   
   return summary;
}

#endif // __RISKMANAGER_MQH__
