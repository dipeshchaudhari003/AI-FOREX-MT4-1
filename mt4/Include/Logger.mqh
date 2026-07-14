//+------------------------------------------------------------------+
//| Logger.mqh                                                       |
//| GoldPilotAI Enterprise v3.0 - Event Logging System               |
//| Trade, error, and event logging with file rotation               |
//+------------------------------------------------------------------+
#ifndef __LOGGER_MQH__
#define __LOGGER_MQH__

#include "Config.mqh"
#include "Globals.mqh"

//====================================================================
// HELPER MACROS
//====================================================================
#define IntToString(x) StringConcatenate(x)

//====================================================================
// LOG LEVEL CONSTANTS
//====================================================================
#define LOG_LEVEL_DEBUG     0
#define LOG_LEVEL_INFO      1
#define LOG_LEVEL_WARNING   2
#define LOG_LEVEL_ERROR     3
#define LOG_LEVEL_CRITICAL  4

//====================================================================
// LOG MESSAGE TYPES
//====================================================================
#define LOG_TYPE_TRADE_ENTRY    "ENTRY"
#define LOG_TYPE_TRADE_EXIT     "EXIT"
#define LOG_TYPE_SL_HIT         "SL_HIT"
#define LOG_TYPE_TP_HIT         "TP_HIT"
#define LOG_TYPE_ERROR          "ERROR"
#define LOG_TYPE_WARNING        "WARNING"
#define LOG_TYPE_INFO           "INFO"
#define LOG_TYPE_SIGNAL         "SIGNAL"
#define LOG_TYPE_RISK           "RISK"
#define LOG_TYPE_SYSTEM         "SYSTEM"

//====================================================================
// LOG FILE PATHS
//====================================================================
string LogFileMain      = "GoldPilotAI_Main.log";
string LogFileTrades    = "GoldPilotAI_Trades.log";
string LogFileErrors    = "GoldPilotAI_Errors.log";
string LogFileSignals   = "GoldPilotAI_Signals.log";

//====================================================================
// LOG LEVEL FILTERING
//====================================================================

//--------------------------------------------------------------------
// Check if message should be logged (by level)
//--------------------------------------------------------------------
bool ShouldLog(int messageLevel)
{
   return (messageLevel >= LogLevelFilter);
}

//--------------------------------------------------------------------
// Get Log Level Name
//--------------------------------------------------------------------
string GetLogLevelName(int level)
{
   switch(level)
   {
      case LOG_LEVEL_DEBUG:    return "DEBUG";
      case LOG_LEVEL_INFO:     return "INFO";
      case LOG_LEVEL_WARNING:  return "WARNING";
      case LOG_LEVEL_ERROR:    return "ERROR";
      case LOG_LEVEL_CRITICAL: return "CRITICAL";
      default:                 return "UNKNOWN";
   }
}

//====================================================================
// CORE LOGGING FUNCTIONS
//====================================================================

//--------------------------------------------------------------------
// Write Log Message
//--------------------------------------------------------------------
void WriteLog(string logFile, string logType, string message, int level)
{
   if(!ShouldLog(level))
      return;
   
   if(!EnableLogging)
      return;
   
   // Build timestamp
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   
   // Build log line
   string logLine = "[" + timestamp + "] [" + GetLogLevelName(level) + "] [" + 
                    logType + "] " + message;
   
   // Write to main log
   int handle = FileOpen(LogFileMain, FILE_READ | FILE_WRITE | FILE_TXT, '\t');
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, logLine);
      FileClose(handle);
   }
   
   // Write to specific log if different
   if(logFile != LogFileMain)
   {
      handle = FileOpen(logFile, FILE_READ | FILE_WRITE | FILE_TXT, '\t');
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, logLine);
         FileClose(handle);
      }
   }
   
   // Also log to journal if PrintToJournal enabled
   if(PrintToJournal)
   {
      Print(logLine);
   }
}

//--------------------------------------------------------------------
// Generic Log Message
//--------------------------------------------------------------------
void LogMessage(string message, int level = LOG_LEVEL_INFO, 
               string logType = LOG_TYPE_INFO)
{
   WriteLog(LogFileMain, logType, message, level);
}

//====================================================================
// TRADE LOGGING
//====================================================================

//--------------------------------------------------------------------
// Log Trade Entry
//--------------------------------------------------------------------
void LogTradeEntry(int ticket, int direction, double entryPrice, 
                  double stopLoss, double takeProfit, double lotSize,
                  string signal, double confidence)
{
   string direction_text = (direction == 1 ? "BUY" : "SELL");
   
   string message = "ENTRY | Ticket:" + IntToString(ticket) + 
                   " | " + direction_text + 
                   " | Price:" + DoubleToString(entryPrice, 5) +
                   " | SL:" + DoubleToString(stopLoss, 5) +
                   " | TP:" + DoubleToString(takeProfit, 5) +
                   " | Lot:" + DoubleToString(lotSize, 2) +
                   " | Signal:" + signal +
                   " | Conf:" + DoubleToString(confidence, 2);
   
   WriteLog(LogFileTrades, LOG_TYPE_TRADE_ENTRY, message, LOG_LEVEL_INFO);
}

//--------------------------------------------------------------------
// Log Trade Exit
//--------------------------------------------------------------------
void LogTradeExit(int ticket, int direction, double entryPrice, 
                 double exitPrice, double profit, string reason)
{
   string direction_text = (direction == 1 ? "BUY" : "SELL");
   
   string message = "EXIT | Ticket:" + IntToString(ticket) + 
                   " | " + direction_text +
                   " | Entry:" + DoubleToString(entryPrice, 5) +
                   " | Exit:" + DoubleToString(exitPrice, 5) +
                   " | Profit:" + DoubleToString(profit, 2) +
                   " | Reason:" + reason;
   
   WriteLog(LogFileTrades, LOG_TYPE_TRADE_EXIT, message, LOG_LEVEL_INFO);
}

//--------------------------------------------------------------------
// Log Stop Loss Hit
//--------------------------------------------------------------------
void LogStopLossHit(int ticket, double price, double slPrice)
{
   string message = "SL_HIT | Ticket:" + IntToString(ticket) + 
                   " | Price:" + DoubleToString(price, 5) +
                   " | SL:" + DoubleToString(slPrice, 5);
   
   WriteLog(LogFileTrades, LOG_TYPE_SL_HIT, message, LOG_LEVEL_INFO);
}

//--------------------------------------------------------------------
// Log Take Profit Hit
//--------------------------------------------------------------------
void LogTakeProfitHit(int ticket, double price, double tpPrice, double profit)
{
   string message = "TP_HIT | Ticket:" + IntToString(ticket) + 
                   " | Price:" + DoubleToString(price, 5) +
                   " | TP:" + DoubleToString(tpPrice, 5) +
                   " | Profit:" + DoubleToString(profit, 2);
   
   WriteLog(LogFileTrades, LOG_TYPE_TP_HIT, message, LOG_LEVEL_INFO);
}

//====================================================================
// SIGNAL LOGGING
//====================================================================

//--------------------------------------------------------------------
// Log Signal Generation
//--------------------------------------------------------------------
void LogSignalGeneration(string signal, double confidence, 
                        string source, string reason)
{
   string message = "Signal:" + signal + 
                   " | Conf:" + DoubleToString(confidence, 2) +
                   " | Source:" + source +
                   " | Reason:" + reason;
   
   WriteLog(LogFileSignals, LOG_TYPE_SIGNAL, message, LOG_LEVEL_INFO);
}

//--------------------------------------------------------------------
// Log Risk Check
//--------------------------------------------------------------------
void LogRiskCheck(double riskAmount, double riskPercent, 
                 bool passed, string reason)
{
   string pass_text = (passed ? "PASS" : "FAIL");
   
   string message = pass_text + " | Risk:" + DoubleToString(riskAmount, 2) +
                   " | %:" + DoubleToString(riskPercent, 2) +
                   " | Reason:" + reason;
   
   WriteLog(LogFileMain, LOG_TYPE_RISK, message, LOG_LEVEL_INFO);
}

//====================================================================
// ERROR & WARNING LOGGING
//====================================================================

//--------------------------------------------------------------------
// Log Error
//--------------------------------------------------------------------
void LogError(string errorMessage, string context = "")
{
   string full_message = errorMessage;
   if(context != "")
      full_message += " [" + context + "]";
   
   WriteLog(LogFileErrors, LOG_TYPE_ERROR, full_message, LOG_LEVEL_ERROR);
}

//--------------------------------------------------------------------
// Log Warning
//--------------------------------------------------------------------
void LogWarning(string warningMessage, string context = "")
{
   string full_message = warningMessage;
   if(context != "")
      full_message += " [" + context + "]";
   
   WriteLog(LogFileErrors, LOG_TYPE_WARNING, full_message, LOG_LEVEL_WARNING);
}

//--------------------------------------------------------------------
// Log Critical Error
//--------------------------------------------------------------------
void LogCritical(string criticalMessage, string context = "")
{
   string full_message = criticalMessage;
   if(context != "")
      full_message += " [" + context + "]";
   
   WriteLog(LogFileErrors, LOG_TYPE_ERROR, full_message, LOG_LEVEL_CRITICAL);
   
   // Always print critical errors
   Print("[CRITICAL] " + full_message);
}

//====================================================================
// SYSTEM LOGGING
//====================================================================

//--------------------------------------------------------------------
// Log EA Startup
//--------------------------------------------------------------------
void LogEAStartup()
{
   string message = "EA Started | Version: 3.0 Enterprise" +
                   " | Symbol:" + Symbol() +
                   " | Timeframe:" + IntToString(Period()) +
                   " | Account:" + IntToString(AccountNumber()) +
                   " | Equity:" + DoubleToString(AccountEquity(), 2);
   
   WriteLog(LogFileMain, LOG_TYPE_SYSTEM, message, LOG_LEVEL_INFO);
}

//--------------------------------------------------------------------
// Log EA Shutdown
//--------------------------------------------------------------------
void LogEAShutdown(string reason = "")
{
   string message = "EA Stopped | Reason:" + (reason == "" ? "Normal" : reason) +
                   " | Equity:" + DoubleToString(AccountEquity(), 2) +
                   " | TotalTrades:" + IntToString(TodayTrades);
   
   WriteLog(LogFileMain, LOG_TYPE_SYSTEM, message, LOG_LEVEL_INFO);
}

//--------------------------------------------------------------------
// Log Configuration Summary
//--------------------------------------------------------------------
void LogConfigurationSummary()
{
   string message = "CONFIG | LotSize:" + DoubleToString(LotSize, 2) +
                   " | RiskPercent:" + DoubleToString(RiskPerTradePercent, 2) +
                   " | MaxDD:" + DoubleToString(MaxDrawdownLimit, 2) +
                   " | UseML:" + IntToString(UseMLSignals) +
                   " | Strategy:" + IntToString(SignalStrategy);
   
   WriteLog(LogFileMain, LOG_TYPE_SYSTEM, message, LOG_LEVEL_INFO);
}

//====================================================================
// PERFORMANCE LOGGING
//====================================================================

//--------------------------------------------------------------------
// Log Daily Summary
//--------------------------------------------------------------------
void LogDailySummary()
{
   double dailyProfit = GetDailyProfit();
   double dailyLoss = GetDailyLoss();
   double winRate = GetWinRate();
   double profitFactor = GetProfitFactor();
   
   string message = "DAILY_SUMMARY | Trades:" + IntToString(TodayTrades) +
                   " | Wins:" + IntToString(WinningTrades) +
                   " | Losses:" + IntToString(LosingTrades) +
                   " | Profit:" + DoubleToString(dailyProfit, 2) +
                   " | Loss:" + DoubleToString(dailyLoss, 2) +
                   " | WinRate:" + DoubleToString(winRate, 2) +
                   " | PF:" + DoubleToString(profitFactor, 2);
   
   WriteLog(LogFileMain, LOG_TYPE_INFO, message, LOG_LEVEL_INFO);
}

//--------------------------------------------------------------------
// Log Account Status
//--------------------------------------------------------------------
void LogAccountStatus()
{
   double equity = AccountEquity();
   double balance = AccountBalance();
   double drawdown = GetCurrentDrawdownPercent();
   
   double marginPercent = (AccountMargin() > 0) ? (AccountFreeMargin() / AccountMargin() * 100) : 0.0;
   
   string message = "ACCOUNT | Equity:" + DoubleToString(equity, 2) +
                   " | Balance:" + DoubleToString(balance, 2) +
                   " | DD%:" + DoubleToString(drawdown, 2) +
                   " | Margin%:" + DoubleToString(marginPercent, 2);
   
   WriteLog(LogFileMain, LOG_TYPE_INFO, message, LOG_LEVEL_INFO);
}

//====================================================================
// FILE MANAGEMENT
//====================================================================

//--------------------------------------------------------------------
// Get Log File Size
//--------------------------------------------------------------------
long GetLogFileSize(string logFile)
{
   int handle = FileOpen(logFile, FILE_READ | FILE_TXT);
   if(handle == INVALID_HANDLE)
      return 0;
   
   long size = FileTell(handle);
   FileClose(handle);
   
   return size;
}

//--------------------------------------------------------------------
// Check if Log File Should Rotate
//--------------------------------------------------------------------
bool ShouldRotateLogFile(string logFile)
{
   if(!EnableLogRotation)
      return false;
   
   long fileSize = GetLogFileSize(logFile);
   long maxSize = LogMaxSizeKB * 1024;  // Convert KB to bytes
   
   return (fileSize > maxSize);
}

//--------------------------------------------------------------------
// Rotate Log File
//--------------------------------------------------------------------
void RotateLogFile(string logFile)
{
   if(!EnableLogRotation)
      return;
   
   // Create backup filename with timestamp
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
   timestamp = StringSubstr(timestamp, 0, 10) + "_" + 
              StringSubstr(timestamp, 11, 5);
   
   string backupFile = logFile + "." + timestamp + ".bak";
   
   // Rename current log to backup
   if(FileOpen(logFile, FILE_READ | FILE_TXT) != INVALID_HANDLE)
   {
      // File exists, create backup
      FileClose(FileOpen(logFile, FILE_READ | FILE_TXT));
      
      // Log rotation event
      WriteLog(LogFileMain, LOG_TYPE_SYSTEM, 
              "LogRotation | " + logFile + " -> " + backupFile,
              LOG_LEVEL_DEBUG);
   }
}

//--------------------------------------------------------------------
// Check and Rotate All Log Files
//--------------------------------------------------------------------
void CheckAndRotateLogFiles()
{
   if(!EnableLogRotation)
      return;
   
   if(ShouldRotateLogFile(LogFileMain))
      RotateLogFile(LogFileMain);
   
   if(ShouldRotateLogFile(LogFileTrades))
      RotateLogFile(LogFileTrades);
   
   if(ShouldRotateLogFile(LogFileErrors))
      RotateLogFile(LogFileErrors);
   
   if(ShouldRotateLogFile(LogFileSignals))
      RotateLogFile(LogFileSignals);
}

//====================================================================
// INITIALIZATION & MAINTENANCE
//====================================================================

//--------------------------------------------------------------------
// Initialize Logger
//--------------------------------------------------------------------
void InitializeLogger()
{
   if(!EnableLogging)
      return;
   
   // Log EA startup
   LogEAStartup();
   
   // Log configuration
   LogConfigurationSummary();
   
   // Log account status
   LogAccountStatus();
}

//--------------------------------------------------------------------
// Periodic Logger Maintenance
//--------------------------------------------------------------------
void MaintainLogger()
{
   if(!EnableLogging)
      return;
   
   // Check for log rotation every 100 ticks
   static int maintenanceCounter = 0;
   maintenanceCounter++;
   
   if(maintenanceCounter >= 100)
   {
      CheckAndRotateLogFiles();
      
      // Log periodic account status (every hour)
      static datetime lastStatusLog = 0;
      if(TimeCurrent() - lastStatusLog >= 3600)
      {
         LogAccountStatus();
         lastStatusLog = TimeCurrent();
      }
      
      maintenanceCounter = 0;
   }
}

//====================================================================
// DIAGNOSTIC LOGGING
//====================================================================

//--------------------------------------------------------------------
// Log Indicator Values
//--------------------------------------------------------------------
void LogIndicatorValues()
{
   if(!DebugLogger)
      return;
   
   string message = "INDICATORS | EMA9:" + DoubleToString(EMA9, 5) +
                   " | EMA20:" + DoubleToString(EMA20, 5) +
                   " | EMA50:" + DoubleToString(EMA50, 5) +
                   " | ATR:" + DoubleToString(ATR, 5) +
                   " | ADX:" + DoubleToString(ADX, 5) +
                   " | RSI:" + DoubleToString(RSI, 2);
   
   WriteLog(LogFileMain, LOG_TYPE_INFO, message, LOG_LEVEL_DEBUG);
}

//--------------------------------------------------------------------
// Log Order Details
//--------------------------------------------------------------------
void LogOrderDetails(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
   {
      LogError("Order not found", IntToString(ticket));
      return;
   }
   
   string message = "ORDER_DETAILS | Ticket:" + IntToString(ticket) +
                   " | Type:" + IntToString(OrderType()) +
                   " | Entry:" + DoubleToString(OrderOpenPrice(), 5) +
                   " | Current:" + DoubleToString(OrderClosePrice(), 5) +
                   " | SL:" + DoubleToString(OrderStopLoss(), 5) +
                   " | TP:" + DoubleToString(OrderTakeProfit(), 5) +
                   " | Lot:" + DoubleToString(OrderTicket(), 2) +
                   " | Profit:" + DoubleToString(OrderProfit(), 2);
   
   WriteLog(LogFileMain, LOG_TYPE_INFO, message, LOG_LEVEL_DEBUG);
}

#endif // __LOGGER_MQH__
