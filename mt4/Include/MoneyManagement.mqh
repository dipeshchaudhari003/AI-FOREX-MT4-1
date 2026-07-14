//+------------------------------------------------------------------+
//| MoneyManagement.mqh                                              |
//| GoldPilotAI Enterprise v3.0 - Strategy Layer                     |
//| Position sizing, equity management, and risk control             |
//+------------------------------------------------------------------+
#ifndef __MONEYMANAGEMENT_MQH__
#define __MONEYMANAGEMENT_MQH__

#include "Config.mqh"
#include "Globals.mqh"
#include "TradeManager.mqh"

//====================================================================
// MONEY MANAGEMENT STRUCTURE
//====================================================================
struct AccountStats
{
   double StartingEquity;
   double CurrentEquity;
   double CurrentBalance;
   double TotalProfit;
   double TotalLoss;
   double MaxDrawdown;
   double MaxDrawdownPercent;
   double UnrealizedPL;
   double RealizedPL;
   double DailyProfit;
   double DailyLoss;
   int DailyWins;
   int DailyLosses;
   double WinRate;
};

//====================================================================
// POSITION SIZING FUNCTIONS
//====================================================================

//--------------------------------------------------------------------
// Get Position Size Based on Account Percent Risk
//--------------------------------------------------------------------
double GetPositionSize(double riskPercent, double slDistancePoints)
{
   return CalculateLotSize(riskPercent, slDistancePoints);
}

//--------------------------------------------------------------------
// Get Position Size Based on Fixed Percent of Equity
//--------------------------------------------------------------------
double GetPositionSizeEquityPercent(double equityPercent)
{
   double equity = AccountEquity();
   double targetRisk = (equity * equityPercent) / 100.0;
   
   // Assume average 100 point SL for calculation
   double slDistance = 100.0;
   
   double lot = targetRisk / (slDistance * 0.01);
   lot = MathRound(lot * 100) / 100;
   
   if(lot < MinimumLotSize) lot = MinimumLotSize;
   if(lot > MaximumLotSize) lot = MaximumLotSize;
   
   return lot;
}

//--------------------------------------------------------------------
// Scale Down Position Size If Account Is In Drawdown
//--------------------------------------------------------------------
double ScalePositionForDrawdown(double baseLotSize, double maxDrawdownPercent)
{
   double currentDrawdown = GetCurrentDrawdownPercent();
   
   if(currentDrawdown <= 0)
      return baseLotSize;  // No drawdown
   
   if(currentDrawdown >= maxDrawdownPercent)
      return 0;  // Stop trading - max drawdown reached
   
   // Scale down linearly
   // If max DD is 10% and current DD is 5%, reduce to 50% position size
   double reductionFactor = 1.0 - (currentDrawdown / maxDrawdownPercent);
   double scaledLot = baseLotSize * reductionFactor;
   
   if(scaledLot < MinimumLotSize)
      return 0;  // Too small to trade
   
   return scaledLot;
}

//====================================================================
// DRAWDOWN TRACKING
//====================================================================

//--------------------------------------------------------------------
// Get Current Drawdown Percent (Peak to Valley)
//--------------------------------------------------------------------
double GetCurrentDrawdownPercent()
{
   double currentEquity = AccountEquity();
   double peakEquity = StartingEquity;
   
   if(currentEquity >= peakEquity)
      return 0;  // No drawdown
   
   double drawdown = peakEquity - currentEquity;
   double drawdownPercent = (drawdown / peakEquity) * 100.0;
   
   return drawdownPercent;
}

//--------------------------------------------------------------------
// Get Unrealized Drawdown (Including Open Positions)
//--------------------------------------------------------------------
double GetUnrealizedDrawdown()
{
   double currentEquity = AccountEquity();
   double peakEquity = StartingEquity;
   
   return (peakEquity - currentEquity);
}

//--------------------------------------------------------------------
// Update Peak Equity (Track New Highs)
//--------------------------------------------------------------------
void UpdatePeakEquity()
{
   double currentEquity = AccountEquity();
   
   if(currentEquity > StartingEquity)
   {
      StartingEquity = currentEquity;
   }
}

//====================================================================
// DAILY RISK LIMITS
//====================================================================

//--------------------------------------------------------------------
// Check If Daily Loss Limit Reached
//--------------------------------------------------------------------
bool IsDailyLossLimitHit()
{
   if(MaxDailyLossPercent <= 0)
      return false;  // No limit
   
   double dailyLoss = GetDailyLoss();
   double equity = AccountEquity();
   double maxAllowedLoss = (equity * MaxDailyLossPercent) / 100.0;
   
   if(dailyLoss >= maxAllowedLoss)
      return true;
   
   return false;
}

//--------------------------------------------------------------------
// Check If Daily Win Limit Reached (Stop at Profit)
//--------------------------------------------------------------------
bool IsDailyWinLimitReached()
{
   if(MaxDailyWinPercent <= 0)
      return false;  // No limit
   
   double dailyWin = GetDailyWin();
   double equity = AccountEquity();
   double maxAllowedWin = (equity * MaxDailyWinPercent) / 100.0;
   
   if(dailyWin >= maxAllowedWin)
      return true;
   
   return false;
}

//--------------------------------------------------------------------
// Check If Max Consecutive Losses Reached
//--------------------------------------------------------------------
bool IsMaxConsecutiveLossesHit()
{
   if(MaxConsecutiveLosses <= 0)
      return false;  // No limit
   
   if(ConsecutiveLosses >= MaxConsecutiveLosses)
      return true;
   
   return false;
}

//====================================================================
// ACCOUNT STATISTICS
//====================================================================

//--------------------------------------------------------------------
// Calculate Daily Profit
//--------------------------------------------------------------------
double GetDailyProfit()
{
   double profit = 0;
   
   // Sum closed trades today
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      // Check if closed today
      datetime closeTime = OrderCloseTime();
      datetime todayStart = iTime(Symbol(), PERIOD_D1, 0);
      
      if(closeTime >= todayStart && OrderProfit() > 0)
      {
         profit += OrderProfit();
      }
   }
   
   // Add unrealized profit from open trades
   profit += GetUnrealizedProfit();
   
   return profit;
}

//--------------------------------------------------------------------
// Calculate Daily Win (Profit)
//--------------------------------------------------------------------
double GetDailyWin()
{
   return GetDailyProfit();
}

//--------------------------------------------------------------------
// Calculate Daily Loss
//--------------------------------------------------------------------
double GetDailyLoss()
{
   double loss = 0;
   
   // Sum closed trades today
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      // Check if closed today
      datetime closeTime = OrderCloseTime();
      datetime todayStart = iTime(Symbol(), PERIOD_D1, 0);
      
      if(closeTime >= todayStart && OrderProfit() < 0)
      {
         loss += MathAbs(OrderProfit());
      }
   }
   
   // Add unrealized loss from open trades
   double unrealizedPL = GetUnrealizedProfit();
   if(unrealizedPL < 0)
   {
      loss += MathAbs(unrealizedPL);
   }
   
   return loss;
}


//--------------------------------------------------------------------
// Calculate Daily Win Count
//--------------------------------------------------------------------
int GetDailyWinCount()
{
   int wins = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      datetime closeTime = OrderCloseTime();
      datetime todayStart = iTime(Symbol(), PERIOD_D1, 0);
      
      if(closeTime >= todayStart && OrderProfit() >= 0)
      {
         wins++;
      }
   }
   
   return wins;
}

//--------------------------------------------------------------------
// Calculate Daily Loss Count
//--------------------------------------------------------------------
int GetDailyLossCount()
{
   int losses = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      datetime closeTime = OrderCloseTime();
      datetime todayStart = iTime(Symbol(), PERIOD_D1, 0);
      
      if(closeTime >= todayStart && OrderProfit() < 0)
      {
         losses++;
      }
   }
   
   return losses;
}

//--------------------------------------------------------------------
// Calculate Win Rate (%)
//--------------------------------------------------------------------
double GetWinRate()
{
   int totalTrades = WinningTrades + LosingTrades;
   
   if(totalTrades == 0)
      return 0;
   
   return ((double)WinningTrades / totalTrades) * 100.0;
}

//--------------------------------------------------------------------
// Calculate Profit Factor (Gross Profit / Gross Loss)
//--------------------------------------------------------------------
double GetProfitFactor()
{
   double grossProfit = 0;
   double grossLoss = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderProfit() > 0)
         grossProfit += OrderProfit();
      else if(OrderProfit() < 0)
         grossLoss += MathAbs(OrderProfit());
   }
   
   if(grossLoss == 0)
      return 0;
   
   return grossProfit / grossLoss;
}

//--------------------------------------------------------------------
// Build Complete Account Statistics
//--------------------------------------------------------------------
AccountStats GetAccountStats()
{
   AccountStats stats;
   
   stats.StartingEquity = StartingEquity;
   stats.CurrentEquity = AccountEquity();
   stats.CurrentBalance = AccountBalance();
   stats.TotalProfit = GetDailyProfit();
   stats.TotalLoss = GetDailyLoss();
   stats.UnrealizedPL = GetUnrealizedProfit();
   stats.RealizedPL = stats.TotalProfit - stats.TotalLoss;
   stats.MaxDrawdown = GetUnrealizedDrawdown();
   stats.MaxDrawdownPercent = GetCurrentDrawdownPercent();
   stats.DailyProfit = GetDailyProfit();
   stats.DailyLoss = GetDailyLoss();
   stats.DailyWins = GetDailyWinCount();
   stats.DailyLosses = GetDailyLossCount();
   stats.WinRate = GetWinRate();
   
   return stats;
}

//====================================================================
// RISK MANAGEMENT CHECKS
//====================================================================

//--------------------------------------------------------------------
// Master Risk Check - Should We Trade?
//--------------------------------------------------------------------
bool IsTradeAllowedByMoneyManagement()
{
   //---
   // Check daily loss limit
   //---
   if(IsDailyLossLimitHit())
   {
      Print("❌ TRADING BLOCKED: Daily loss limit reached");
      return false;
   }
   
   //---
   // Check daily win limit
   //---
   if(IsDailyWinLimitReached())
   {
      Print("✅ TRADING PAUSED: Daily profit target reached");
      return false;
   }
   
   //---
   // Check consecutive losses
   //---
   if(IsMaxConsecutiveLossesHit())
   {
      Print("❌ TRADING BLOCKED: Max consecutive losses hit");
      return false;
   }
   
   //---
   // Check drawdown limit
   //---
   double currentDD = GetCurrentDrawdownPercent();
   if(currentDD >= MaxDrawdownLimit)
   {
      Print("❌ TRADING BLOCKED: Max drawdown limit reached (", 
            DoubleToString(currentDD, 2), "%)");
      return false;
   }
   
   //---
   // Check margin
   //---
   if(AccountFreeMargin() < 100)
   {
      Print("❌ TRADING BLOCKED: Insufficient margin");
      return false;
   }
   
   return true;
}

//====================================================================
// MONEY MANAGEMENT DISPLAY (DEBUG)
//====================================================================

//--------------------------------------------------------------------
// Log Money Management Status
//--------------------------------------------------------------------
void LogMoneyManagementStatus()
{
   AccountStats stats = GetAccountStats();
   
   Print("===== MONEY MANAGEMENT STATUS =====");
   Print("Equity: $", DoubleToString(stats.CurrentEquity, 2));
   Print("Balance: $", DoubleToString(stats.CurrentBalance, 2));
   Print("Unrealized P&L: $", DoubleToString(stats.UnrealizedPL, 2));
   Print("Daily Profit: $", DoubleToString(stats.DailyProfit, 2));
   Print("Daily Loss: $", DoubleToString(stats.DailyLoss, 2));
   Print("Drawdown: ", DoubleToString(stats.MaxDrawdownPercent, 2), "%");
   Print("Win Rate: ", DoubleToString(stats.WinRate, 2), "%");
   Print("Consecutive Losses: ", ConsecutiveLosses, "/", MaxConsecutiveLosses);
   Print("Daily Trades: ", TodayTrades, "/", MaxTradesPerDay);
   Print("====================================");
}

#endif // __MONEYMANAGEMENT_MQH__
