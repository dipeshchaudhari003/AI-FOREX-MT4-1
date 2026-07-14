//+------------------------------------------------------------------+
//| Dashboard.mqh                                                   |
//| GoldPilotAI Enterprise v3.0 - Real-Time Chart Display           |
//| Display metrics, alerts, and trading status on chart             |
//+------------------------------------------------------------------+
#ifndef __DASHBOARD_MQH__
#define __DASHBOARD_MQH__

#include "Config.mqh"
#include "Globals.mqh"
#include "Statistics.mqh"
#include "MoneyManagement.mqh"

//====================================================================
// DASHBOARD DISPLAY CONSTANTS
//====================================================================
#define CHART_CORNER CORNER_LEFT_UPPER
#define TEXT_X_OFFSET 10
#define TEXT_Y_OFFSET 10
#define TEXT_LINE_HEIGHT 20
#define DASHBOARD_FONT "Arial"
#define DASHBOARD_FONT_SIZE 10

//====================================================================
// DASHBOARD LINE INDEXES
//====================================================================
#define LINE_HEADER 0
#define LINE_ACCOUNT 1
#define LINE_TRADES 2
#define LINE_PERFORMANCE 3
#define LINE_SIGNAL 4
#define LINE_RISK 5
#define LINE_ALERTS 6

//====================================================================
// DASHBOARD STATE
//====================================================================
bool DashboardInitialized = false;

//====================================================================
// INITIALIZATION
//====================================================================

//--------------------------------------------------------------------
// Initialize Dashboard
//--------------------------------------------------------------------
void InitializeDashboard()
{
   if(!EnableDashboard)
      return;
   
   DashboardInitialized = true;
}

//====================================================================
// CORE DISPLAY FUNCTIONS
//====================================================================

//--------------------------------------------------------------------
// Create/Update Text Label
//--------------------------------------------------------------------
void UpdateDashboardText(int lineIndex, string text, color textColor)
{
   if(!EnableDashboard)
      return;
   
   int yPos = TEXT_Y_OFFSET + (lineIndex * TEXT_LINE_HEIGHT);
   string objName = "Dashboard_Line_" + IntToString(lineIndex);
   
   // Delete old object
   ObjectDelete(objName);
   
   // Create new text object
   ObjectCreate(objName, OBJ_TEXT, 0, TimeCurrent(), 0);
   ObjectSet(objName, OBJPROP_TIME1, TimeCurrent());
   ObjectSet(objName, OBJPROP_PRICE1, Ask);
   ObjectSet(objName, OBJPROP_XDISTANCE, TEXT_X_OFFSET);
   ObjectSet(objName, OBJPROP_YDISTANCE, yPos);
   ObjectSet(objName, OBJPROP_FONT, DASHBOARD_FONT);
   ObjectSet(objName, OBJPROP_FONTSIZE, DASHBOARD_FONT_SIZE);
   ObjectSet(objName, OBJPROP_COLOR, textColor);
   ObjectSetText(objName, text);
}

//--------------------------------------------------------------------
// Get Color Based on Value
//--------------------------------------------------------------------
color GetStatusColor(double value, double threshold, bool higherIsBetter)
{
   if(higherIsBetter)
   {
      if(value >= threshold)
         return clrLimeGreen;
      else if(value >= threshold * 0.5)
         return clrYellow;
      else
         return clrOrangeRed;
   }
   else
   {
      if(value <= threshold)
         return clrLimeGreen;
      else if(value <= threshold * 1.5)
         return clrYellow;
      else
         return clrOrangeRed;
   }
}

//====================================================================
// ACCOUNT DISPLAY
//====================================================================

//--------------------------------------------------------------------
// Display Account Information
//--------------------------------------------------------------------
void DisplayAccountInfo()
{
   if(!EnableDashboard)
      return;
   
   double equity = AccountEquity();
   double balance = AccountBalance();
   double profit = equity - balance;
   
   string accountText = "ACCOUNT | Equity: $" + DoubleToString(equity, 2) +
                       " | Balance: $" + DoubleToString(balance, 2) +
                       " | P&L: $" + DoubleToString(profit, 2);
   
   color textColor = (profit >= 0 ? clrLimeGreen : clrRed);
   UpdateDashboardText(LINE_ACCOUNT, accountText, textColor);
}

//====================================================================
// TRADE STATISTICS DISPLAY
//====================================================================

//--------------------------------------------------------------------
// Display Trade Count and Win Rate
//--------------------------------------------------------------------
void DisplayTradeStatistics()
{
   if(!EnableDashboard)
      return;
   
   DailyStats stats = GetDailyStatistics();
   
   string tradesText = "TRADES | Total: " + IntToString(stats.TotalTrades) +
                      " | Wins: " + IntToString(stats.WinningTrades) +
                      " | Losses: " + IntToString(stats.LosingTrades) +
                      " | WR: " + DoubleToString(stats.WinRate, 1) + "%";
   
   color textColor = GetStatusColor(stats.WinRate, 50.0, true);
   UpdateDashboardText(LINE_TRADES, tradesText, textColor);
}

//--------------------------------------------------------------------
// Display Performance Metrics
//--------------------------------------------------------------------
void DisplayPerformanceMetrics()
{
   if(!EnableDashboard)
      return;
   
   DailyStats stats = GetDailyStatistics();
   
   string performanceText = "PERF | Profit: $" + DoubleToString(stats.GrossProfit, 2) +
                           " | Loss: $" + DoubleToString(stats.GrossLoss, 2) +
                           " | PF: " + DoubleToString(stats.ProfitFactor, 2) +
                           " | DD: " + DoubleToString(stats.MaxDrawdown, 2) + "%";
   
   color textColor = GetStatusColor(stats.ProfitFactor, 1.5, true);
   UpdateDashboardText(LINE_PERFORMANCE, performanceText, textColor);
}

//====================================================================
// SIGNAL DISPLAY
//====================================================================

//--------------------------------------------------------------------
// Display Current Signal
//--------------------------------------------------------------------
void DisplaySignalInfo(int signal, double confidence, string source)
{
   if(!EnableDashboard)
      return;
   
   string signalText = "SIGNAL | ";
   
   if(signal == 1)
      signalText += "BUY";
   else if(signal == -1)
      signalText += "SELL";
   else
      signalText += "HOLD";
   
   signalText += " | Conf: " + DoubleToString(confidence, 2) +
                " | Source: " + source;
   
   color textColor = clrWhite;
   if(signal == 1)
      textColor = clrLimeGreen;
   else if(signal == -1)
      textColor = clrRed;
   
   UpdateDashboardText(LINE_SIGNAL, signalText, textColor);
}

//====================================================================
// RISK DISPLAY
//====================================================================

//--------------------------------------------------------------------
// Display Risk Metrics
//--------------------------------------------------------------------
void DisplayRiskMetrics()
{
   if(!EnableDashboard)
      return;
   
   AccountStats accStats = GetAccountStats();
   double riskRemaining = GetRiskRemainingToday();
   
   string riskText = "RISK | MaxDD: " + DoubleToString(accStats.MaxDrawdownPercent, 2) + "%" +
                    " | Remaining: $" + DoubleToString(riskRemaining, 2) +
                    " | Margin: " + DoubleToString(AccountFreeMargin() / AccountMargin() * 100, 1) + "%";
   
   color textColor = GetStatusColor(riskRemaining, 100.0, true);
   UpdateDashboardText(LINE_RISK, riskText, textColor);
}

//====================================================================
// ALERT DISPLAY
//====================================================================

//--------------------------------------------------------------------
// Display System Alerts
//--------------------------------------------------------------------
void DisplayAlerts()
{
   if(!EnableDashboard)
      return;
   
   string alertText = "ALERTS | ";
   color alertColor = clrWhite;
   
   // Check for critical conditions
   if(IsDailyLossLimitHit())
   {
      alertText += "[DAILY LOSS LIMIT HIT]";
      alertColor = clrRed;
   }
   else if(IsDailyWinLimitReached())
   {
      alertText += "[DAILY WIN LIMIT REACHED]";
      alertColor = clrYellow;
   }
   else if(IsMaxConsecutiveLossesHit())
   {
      alertText += "[MAX CONSECUTIVE LOSSES HIT]";
      alertColor = clrOrangeRed;
   }
   else if(GetCurrentDrawdownPercent() > MaxDrawdownLimit * 0.8)
   {
      alertText += "[WARNING: HIGH DRAWDOWN]";
      alertColor = clrOrange;
   }
   else
   {
      alertText += "NORMAL";
      alertColor = clrLimeGreen;
   }
   
   UpdateDashboardText(LINE_ALERTS, alertText, alertColor);
}

//====================================================================
// MAIN DASHBOARD UPDATE
//====================================================================

//--------------------------------------------------------------------
// Update Complete Dashboard (MASTER FUNCTION)
//--------------------------------------------------------------------
void UpdateDashboard(int signal = 0, double confidence = 0.0, 
                    string source = "")
{
   if(!EnableDashboard)
      return;
   
   // Header
   UpdateDashboardText(LINE_HEADER, "=== GoldPilotAI Dashboard ===", clrWhite);
   
   // Account info
   DisplayAccountInfo();
   
   // Trade statistics
   DisplayTradeStatistics();
   
   // Performance
   DisplayPerformanceMetrics();
   
   // Signal
   DisplaySignalInfo(signal, confidence, source);
   
   // Risk
   DisplayRiskMetrics();
   
   // Alerts
   DisplayAlerts();
}

//====================================================================
// CHART COMMENT (For platforms without text objects)
//====================================================================

//--------------------------------------------------------------------
// Build Comment String
//--------------------------------------------------------------------
string BuildDashboardComment()
{
   if(!EnableDashboard)
      return "";
   
   DailyStats stats = GetDailyStatistics();
   AccountStats accStats = GetAccountStats();
   
   string comment = "=== GoldPilotAI Dashboard ===\n\n";
   
   comment += "ACCOUNT:\n";
   comment += "  Equity: $" + DoubleToString(accStats.CurrentEquity, 2) + "\n";
   comment += "  Balance: $" + DoubleToString(accStats.CurrentBalance, 2) + "\n";
   comment += "  P&L: $" + DoubleToString(accStats.CurrentEquity - accStats.CurrentBalance, 2) + "\n\n";
   
   comment += "TRADES TODAY:\n";
   comment += "  Total: " + IntToString(stats.TotalTrades) + "\n";
   comment += "  Wins: " + IntToString(stats.WinningTrades) + "\n";
   comment += "  Losses: " + IntToString(stats.LosingTrades) + "\n";
   comment += "  Win Rate: " + DoubleToString(stats.WinRate, 2) + "%\n\n";
   
   comment += "PERFORMANCE:\n";
   comment += "  Profit: $" + DoubleToString(stats.GrossProfit, 2) + "\n";
   comment += "  Loss: $" + DoubleToString(stats.GrossLoss, 2) + "\n";
   comment += "  PF: " + DoubleToString(stats.ProfitFactor, 2) + "\n";
   comment += "  DD: " + DoubleToString(stats.MaxDrawdown, 2) + "%\n\n";
   
   comment += "RISK:\n";
   comment += "  Max DD: " + DoubleToString(accStats.MaxDrawdownPercent, 2) + "%\n";
   comment += "  Margin: " + DoubleToString(AccountFreeMargin() / AccountMargin() * 100, 1) + "%\n";
   
   return comment;
}

//--------------------------------------------------------------------
// Update Chart Comment
//--------------------------------------------------------------------
void UpdateChartComment()
{
   if(!EnableDashboard)
      return;
   
   string comment = BuildDashboardComment();
   Comment(comment);
}

//====================================================================
// ENTRY/EXIT MARKERS
//====================================================================

//--------------------------------------------------------------------
// Draw Entry Marker
//--------------------------------------------------------------------
void DrawEntryMarker(double price, bool isBuy)
{
   if(!ShowEntryMarkers)
      return;
   
   string markerName = "Entry_" + IntToString(TimeCurrent());
   color markerColor = (isBuy ? clrLimeGreen : clrRed);
   int markerType = (isBuy ? SYMBOL_ARROWUP : SYMBOL_ARROWDOWN);
   
   ArrowCreate(markerName, TimeCurrent(), price, markerType, markerColor);
}

//--------------------------------------------------------------------
// Draw Exit Marker
//--------------------------------------------------------------------
void DrawExitMarker(double price, bool isProfit)
{
   if(!ShowExitMarkers)
      return;
   
   string markerName = "Exit_" + IntToString(TimeCurrent());
   color markerColor = (isProfit ? clrLimeGreen : clrRed);
   
   // Profit = filled circle, loss = X
   ObjectCreate(markerName, OBJ_TEXT, 0, TimeCurrent(), price);
   ObjectSet(markerName, OBJPROP_FONT, "Wingdings");
   ObjectSet(markerName, OBJPROP_FONTSIZE, 12);
   ObjectSet(markerName, OBJPROP_COLOR, markerColor);
   ObjectSetText(markerName, (isProfit ? "l" : "r"));
}

//====================================================================
// HELPER FUNCTIONS
//====================================================================

//--------------------------------------------------------------------
// Arrow Create Helper
//--------------------------------------------------------------------
void ArrowCreate(string name, datetime time, double price, int type, color arrowColor)
{
   ObjectCreate(name, OBJ_ARROW, 0, time, price);
   ObjectSet(name, OBJPROP_ARROWCODE, type);
   ObjectSet(name, OBJPROP_COLOR, arrowColor);
}

//--------------------------------------------------------------------
// Clean Up Old Markers
//--------------------------------------------------------------------
void CleanupOldMarkers()
{
   if(!ShowEntryMarkers && !ShowExitMarkers)
      return;
   
   int objCount = ObjectsTotal();
   
   for(int i = objCount - 1; i >= 0; i--)
   {
      string objName = ObjectName(i);
      
      // Remove markers older than max history bars
      if(StringSubstr(objName, 0, 6) == "Entry_" || 
         StringSubstr(objName, 0, 5) == "Exit_")
      {
         datetime objTime = ObjectGet(objName, OBJPROP_TIME1);
         int barDiff = (TimeCurrent() - objTime) / Period() / 60;
         
         if(barDiff > MaxHistoryBars)
         {
            ObjectDelete(objName);
         }
      }
   }
}

//====================================================================
// DISPLAY UTILITIES
//====================================================================

//--------------------------------------------------------------------
// Format Value for Display
//--------------------------------------------------------------------
string FormatValue(double value, int decimals)
{
   return DoubleToString(value, decimals);
}

//--------------------------------------------------------------------
// Get Status Text
//--------------------------------------------------------------------
string GetStatusText(bool isNormal)
{
   return (isNormal ? "NORMAL" : "WARNING");
}

//====================================================================
// CLEANUP
//====================================================================

//--------------------------------------------------------------------
// Clean Dashboard Objects
//--------------------------------------------------------------------
void CleanupDashboard()
{
   if(!EnableDashboard)
      return;
   
   int objCount = ObjectsTotal();
   
   for(int i = objCount - 1; i >= 0; i--)
   {
      string objName = ObjectName(i);
      
      if(StringSubstr(objName, 0, 14) == "Dashboard_Line")
      {
         ObjectDelete(objName);
      }
   }
}

#endif // __DASHBOARD_MQH__
