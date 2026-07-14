//+------------------------------------------------------------------+
//| Statistics.mqh                                                   |
//| GoldPilotAI Enterprise v3.0 - Trade Statistics & Analytics       |
//| Performance metrics, drawdown analysis, strategy metrics          |
//+------------------------------------------------------------------+
#ifndef __STATISTICS_MQH__
#define __STATISTICS_MQH__

#include "Config.mqh"
#include "Globals.mqh"
#include "TradeManager.mqh"

//====================================================================
// STATISTICS STRUCTURES
//====================================================================

struct DailyStats
{
   int TotalTrades;
   int WinningTrades;
   int LosingTrades;
   double GrossProfit;
   double GrossLoss;
   double NetProfit;
   double WinRate;
   double ProfitFactor;
   double AvgWinSize;
   double AvgLossSize;
   double LargestWin;
   double LargestLoss;
   double MaxDrawdown;
   int ConsecutiveWins;
   int ConsecutiveLosses;
};

struct MonthlyStats
{
   int TotalTrades;
   int WinningTrades;
   int LosingTrades;
   double GrossProfit;
   double GrossLoss;
   double NetProfit;
   double WinRate;
   double ProfitFactor;
   double MaxDrawdown;
   double ReturnPercent;
};

struct StrategyStats
{
   string StrategyName;
   int SignalSource;          // 0=Technical, 1=ML, 2=Confluence
   int TotalTrades;
   int WinningTrades;
   int LosingTrades;
   double GrossProfit;
   double GrossLoss;
   double WinRate;
   double ProfitFactor;
   int ConsecutiveWins;
   int ConsecutiveLosses;
};

//====================================================================
// DAILY STATISTICS CALCULATION
//====================================================================

//--------------------------------------------------------------------
// Calculate Daily Win Rate
//--------------------------------------------------------------------
double CalculateDailyWinRate()
{
   if(WinningTrades + LosingTrades == 0)
      return 0.0;
   
   return (double)WinningTrades / (double)(WinningTrades + LosingTrades) * 100.0;
}

//--------------------------------------------------------------------
// Calculate Daily Profit Factor
//--------------------------------------------------------------------
double CalculateDailyProfitFactor()
{
   double dailyLoss = GetDailyLoss();
   
   if(dailyLoss <= 0)
      return 0.0;
   
   double dailyProfit = GetDailyProfit();
   
   return dailyProfit / MathAbs(dailyLoss);
}

//--------------------------------------------------------------------
// Get Daily Statistics Structure
//--------------------------------------------------------------------
DailyStats GetDailyStatistics()
{
   DailyStats stats;
   
   stats.TotalTrades = TodayTrades;
   stats.WinningTrades = WinningTrades;
   stats.LosingTrades = LosingTrades;
   stats.GrossProfit = GetDailyProfit();
   stats.GrossLoss = GetDailyLoss();
   stats.NetProfit = stats.GrossProfit + stats.GrossLoss;  // Loss is negative
   stats.WinRate = CalculateDailyWinRate();
   stats.ProfitFactor = CalculateDailyProfitFactor();
   
   // Calculate average win/loss
   if(stats.WinningTrades > 0)
      stats.AvgWinSize = stats.GrossProfit / stats.WinningTrades;
   else
      stats.AvgWinSize = 0.0;
   
   if(stats.LosingTrades > 0)
      stats.AvgLossSize = stats.GrossLoss / stats.LosingTrades;
   else
      stats.AvgLossSize = 0.0;
   
   // Largest win/loss (simplified - would need order history)
   stats.LargestWin = 0.0;
   stats.LargestLoss = 0.0;
   
   // Drawdown (current)
   stats.MaxDrawdown = GetCurrentDrawdownPercent();
   
   // Consecutive wins/losses
   stats.ConsecutiveWins = 0;
   stats.ConsecutiveLosses = 0;
   
   return stats;
}

//====================================================================
// MONTHLY STATISTICS CALCULATION
//====================================================================

//--------------------------------------------------------------------
// Count Monthly Trades
//--------------------------------------------------------------------
int CountMonthlyTrades()
{
   int tradeCount = 0;
   datetime monthStart = StringToTime(
      IntToString(Year()) + "." + 
      IntToString(Month()) + ".01 00:00:00");
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderCloseTime() >= monthStart && 
         OrderSymbol() == Symbol() && 
         OrderMagicNumber() == MagicNumber)
      {
         tradeCount++;
      }
   }
   
   return tradeCount;
}

//--------------------------------------------------------------------
// Calculate Monthly Profit
//--------------------------------------------------------------------
double CalculateMonthlyProfit()
{
   double monthlyProfit = 0.0;
   datetime monthStart = StringToTime(
      IntToString(Year()) + "." + 
      IntToString(Month()) + ".01 00:00:00");
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderCloseTime() >= monthStart && 
         OrderSymbol() == Symbol() && 
         OrderMagicNumber() == MagicNumber &&
         OrderProfit() > 0)
      {
         monthlyProfit += OrderProfit();
      }
   }
   
   return monthlyProfit;
}

//--------------------------------------------------------------------
// Calculate Monthly Loss
//--------------------------------------------------------------------
double CalculateMonthlyLoss()
{
   double monthlyLoss = 0.0;
   datetime monthStart = StringToTime(
      IntToString(Year()) + "." + 
      IntToString(Month()) + ".01 00:00:00");
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderCloseTime() >= monthStart && 
         OrderSymbol() == Symbol() && 
         OrderMagicNumber() == MagicNumber &&
         OrderProfit() < 0)
      {
         monthlyLoss += OrderProfit();
      }
   }
   
   return monthlyLoss;
}

//--------------------------------------------------------------------
// Get Monthly Statistics Structure
//--------------------------------------------------------------------
MonthlyStats GetMonthlyStatistics()
{
   MonthlyStats stats;
   
   stats.TotalTrades = CountMonthlyTrades();
   
   // Calculate wins/losses by analyzing order history
   stats.WinningTrades = 0;
   stats.LosingTrades = 0;
   
   datetime monthStart = StringToTime(
      IntToString(Year()) + "." + 
      IntToString(Month()) + ".01 00:00:00");
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderCloseTime() >= monthStart && 
         OrderSymbol() == Symbol() && 
         OrderMagicNumber() == MagicNumber)
      {
         if(OrderProfit() > 0)
            stats.WinningTrades++;
         else if(OrderProfit() < 0)
            stats.LosingTrades++;
      }
   }
   
   stats.GrossProfit = CalculateMonthlyProfit();
   stats.GrossLoss = CalculateMonthlyLoss();
   stats.NetProfit = stats.GrossProfit + stats.GrossLoss;
   
   // Win rate
   if(stats.TotalTrades > 0)
      stats.WinRate = (double)stats.WinningTrades / stats.TotalTrades * 100.0;
   else
      stats.WinRate = 0.0;
   
   // Profit factor
   if(stats.GrossLoss < 0)
      stats.ProfitFactor = stats.GrossProfit / MathAbs(stats.GrossLoss);
   else
      stats.ProfitFactor = 0.0;
   
   // Drawdown (use current as approximation)
   stats.MaxDrawdown = GetCurrentDrawdownPercent();
   
   // Return percent
   if(StartingEquity > 0)
      stats.ReturnPercent = (stats.NetProfit / StartingEquity) * 100.0;
   else
      stats.ReturnPercent = 0.0;
   
   return stats;
}

//====================================================================
// STRATEGY-SPECIFIC STATISTICS
//====================================================================

//--------------------------------------------------------------------
// Get Statistics by Signal Source
//--------------------------------------------------------------------
StrategyStats GetStrategyStatistics(int signalSource)
{
   StrategyStats stats;
   
   switch(signalSource)
   {
      case 0: stats.StrategyName = "Technical"; break;
      case 1: stats.StrategyName = "ML"; break;
      case 2: stats.StrategyName = "Confluence"; break;
      default: stats.StrategyName = "Unknown"; break;
   }
   
   stats.SignalSource = signalSource;
   stats.TotalTrades = 0;
   stats.WinningTrades = 0;
   stats.LosingTrades = 0;
   stats.GrossProfit = 0.0;
   stats.GrossLoss = 0.0;
   
   // Scan order history and filter by signal source
   // Note: Requires storing signal source in order comment
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderSymbol() != Symbol() || 
         OrderMagicNumber() != MagicNumber)
         continue;
      
      // Check if this trade matches signal source
      // (Implementation depends on how source is stored)
      
      stats.TotalTrades++;
      
      if(OrderProfit() > 0)
      {
         stats.WinningTrades++;
         stats.GrossProfit += OrderProfit();
      }
      else if(OrderProfit() < 0)
      {
         stats.LosingTrades++;
         stats.GrossLoss += OrderProfit();
      }
   }
   
   // Calculate metrics
   if(stats.TotalTrades > 0)
      stats.WinRate = (double)stats.WinningTrades / stats.TotalTrades * 100.0;
   else
      stats.WinRate = 0.0;
   
   if(stats.GrossLoss < 0)
      stats.ProfitFactor = stats.GrossProfit / MathAbs(stats.GrossLoss);
   else
      stats.ProfitFactor = 0.0;
   
   return stats;
}

//====================================================================
// PERFORMANCE METRICS
//====================================================================

//--------------------------------------------------------------------
// Calculate Sharpe Ratio (Simplified)
//--------------------------------------------------------------------
double CalculateSharpeRatio(double riskFreeRate = 0.02)
{
   // Simplified: uses daily returns
   // Returns are: (daily profit) / (starting equity)
   
   double dailyReturn = GetDailyProfit() / AccountEquity();
   double volatility = 0.05;  // Approximation - would need historical data
   
   return (dailyReturn - riskFreeRate) / volatility;
}

//--------------------------------------------------------------------
// Calculate Sortino Ratio (Simplified)
//--------------------------------------------------------------------
double CalculateSortinoRatio(double riskFreeRate = 0.02)
{
   // Only considers downside deviation
   double dailyReturn = GetDailyProfit() / AccountEquity();
   double downvol = 0.03;  // Approximation
   
   return (dailyReturn - riskFreeRate) / downvol;
}

//--------------------------------------------------------------------
// Calculate Recovery Factor
//--------------------------------------------------------------------
double CalculateRecoveryFactor()
{
   double maxDrawdown = GetCurrentDrawdownPercent();
   double totalProfit = GetDailyProfit();
   
   if(maxDrawdown <= 0)
      return 0.0;
   
   return totalProfit / maxDrawdown;
}

//--------------------------------------------------------------------
// Calculate Profit Factor (Already in MoneyManagement)
//--------------------------------------------------------------------
double GetProfitFactorStatistics()
{
   return GetProfitFactor();
}

//====================================================================
// CUMULATIVE STATISTICS
//====================================================================

//--------------------------------------------------------------------
// Get Total All-Time Trades
//--------------------------------------------------------------------
int GetTotalAllTimeTrades()
{
   int totalTrades = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderSymbol() == Symbol() && 
         OrderMagicNumber() == MagicNumber)
      {
         totalTrades++;
      }
   }
   
   return totalTrades;
}

//--------------------------------------------------------------------
// Get Total All-Time Profit
//--------------------------------------------------------------------
double GetTotalAllTimeProfit()
{
   double totalProfit = 0.0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderSymbol() == Symbol() && 
         OrderMagicNumber() == MagicNumber &&
         OrderProfit() > 0)
      {
         totalProfit += OrderProfit();
      }
   }
   
   return totalProfit;
}

//--------------------------------------------------------------------
// Get Total All-Time Loss
//--------------------------------------------------------------------
double GetTotalAllTimeLoss()
{
   double totalLoss = 0.0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderSymbol() == Symbol() && 
         OrderMagicNumber() == MagicNumber &&
         OrderProfit() < 0)
      {
         totalLoss += OrderProfit();
      }
   }
   
   return totalLoss;
}

//--------------------------------------------------------------------
// Get All-Time Return Percent
//--------------------------------------------------------------------
double GetAllTimeReturnPercent()
{
   if(StartingEquity <= 0)
      return 0.0;
   
   double totalProfit = GetTotalAllTimeProfit() + GetTotalAllTimeLoss();
   return (totalProfit / StartingEquity) * 100.0;
}

//====================================================================
// STATISTICS REPORTING
//====================================================================

//--------------------------------------------------------------------
// Log Daily Statistics
//--------------------------------------------------------------------
void LogDailyStatistics()
{
   if(!EnableStatisticsLogging)
      return;
   
   DailyStats stats = GetDailyStatistics();
   
   Print("===== DAILY STATISTICS =====");
   Print("Trades:    ", stats.TotalTrades);
   Print("Wins:      ", stats.WinningTrades);
   Print("Losses:    ", stats.LosingTrades);
   Print("Win Rate:  ", DoubleToString(stats.WinRate, 2), "%");
   Print("Profit:    ", DoubleToString(stats.GrossProfit, 2));
   Print("Loss:      ", DoubleToString(stats.GrossLoss, 2));
   Print("Net:       ", DoubleToString(stats.NetProfit, 2));
   Print("PF:        ", DoubleToString(stats.ProfitFactor, 2));
   Print("Avg Win:   ", DoubleToString(stats.AvgWinSize, 2));
   Print("Avg Loss:  ", DoubleToString(stats.AvgLossSize, 2));
   Print("Max DD:    ", DoubleToString(stats.MaxDrawdown, 2), "%");
   Print("=============================");
}

//--------------------------------------------------------------------
// Log Monthly Statistics
//--------------------------------------------------------------------
void LogMonthlyStatistics()
{
   if(!EnableStatisticsLogging)
      return;
   
   MonthlyStats stats = GetMonthlyStatistics();
   
   Print("===== MONTHLY STATISTICS =====");
   Print("Trades:    ", stats.TotalTrades);
   Print("Wins:      ", stats.WinningTrades);
   Print("Losses:    ", stats.LosingTrades);
   Print("Win Rate:  ", DoubleToString(stats.WinRate, 2), "%");
   Print("Profit:    ", DoubleToString(stats.GrossProfit, 2));
   Print("Loss:      ", DoubleToString(stats.GrossLoss, 2));
   Print("Net:       ", DoubleToString(stats.NetProfit, 2));
   Print("PF:        ", DoubleToString(stats.ProfitFactor, 2));
   Print("Return:    ", DoubleToString(stats.ReturnPercent, 2), "%");
   Print("Max DD:    ", DoubleToString(stats.MaxDrawdown, 2), "%");
   Print("================================");
}

//--------------------------------------------------------------------
// Log All-Time Statistics
//--------------------------------------------------------------------
void LogAllTimeStatistics()
{
   if(!EnableStatisticsLogging)
      return;
   
   int totalTrades = GetTotalAllTimeTrades();
   double totalProfit = GetTotalAllTimeProfit();
   double totalLoss = GetTotalAllTimeLoss();
   double returnPct = GetAllTimeReturnPercent();
   
   Print("===== ALL-TIME STATISTICS =====");
   Print("Total Trades: ", totalTrades);
   Print("Total Profit: ", DoubleToString(totalProfit, 2));
   Print("Total Loss:   ", DoubleToString(totalLoss, 2));
   Print("Total Return: ", DoubleToString(returnPct, 2), "%");
   Print("Net Profit:   ", DoubleToString(totalProfit + totalLoss, 2));
   Print("================================");
}

//--------------------------------------------------------------------
// Get Statistics Summary String
//--------------------------------------------------------------------
string GetStatisticsSummary()
{
   DailyStats stats = GetDailyStatistics();
   
   return "Trades:" + IntToString(stats.TotalTrades) +
          " | W:" + IntToString(stats.WinningTrades) +
          " L:" + IntToString(stats.LosingTrades) +
          " | WR:" + DoubleToString(stats.WinRate, 1) + "%" +
          " | P&L:" + DoubleToString(stats.NetProfit, 2) +
          " | PF:" + DoubleToString(stats.ProfitFactor, 2);
}

#endif // __STATISTICS_MQH__
