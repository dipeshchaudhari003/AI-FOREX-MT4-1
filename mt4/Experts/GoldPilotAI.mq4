//+------------------------------------------------------------------+
//| GoldPilotAI.mq4                                                 |
//| GoldPilotAI Enterprise v3.0 - Main Expert Advisor               |
//| Modular XAUUSD M1 Gold Scalper with ML Integration              |
//+------------------------------------------------------------------+
#property copyright "GoldPilotAI Enterprise"
#property link "https://github.com/dipeshchaudhari019/AI-FOREX-MT4"
#property version "3.0"
#property strict

//====================================================================
// MODULE INCLUDES (CORE LAYER)
//====================================================================
#include <Config.mqh>
#include <Globals.mqh>
#include <Utilities.mqh>

//====================================================================
// MODULE INCLUDES (STRATEGY LAYER)
//====================================================================
#include <Indicators.mqh>
#include <Filters.mqh>
#include <EntryLogic.mqh>
#include <ExitLogic.mqh>
#include <TradeManager.mqh>
#include <MoneyManagement.mqh>
#include <RiskManager.mqh>

//====================================================================
// MODULE INCLUDES (AI LAYER)
//====================================================================
#include <MLPredictor.mqh>
#include <ConfidenceScore.mqh>
#include <SignalEngine.mqh>

//====================================================================
// MODULE INCLUDES (ANALYTICS LAYER)
//====================================================================
#include <Logger.mqh>
#include <Statistics.mqh>
#include <Dashboard.mqh>

//====================================================================
// EA CONSTANTS
//====================================================================
#define EA_VERSION "3.0 Enterprise"
#define EA_NAME "GoldPilotAI"

//====================================================================
// INITIALIZATION
//====================================================================
int OnInit()
{
   // Set EA metadata
   string eaVersion = EA_VERSION;
   string eaName = EA_NAME;
   
   // Initialize base system
   if(StartingEquity == 0)
      StartingEquity = AccountEquity();
   
   if(DailyStartEquity == 0)
      DailyStartEquity = AccountEquity();
   
   // Initialize modules in order
   InitializeLogger();
   InitializeDashboard();
   InitializeMLSystem();
   
   // Log startup
   LogMessage("EA initialized successfully", LOG_LEVEL_INFO, LOG_TYPE_SYSTEM);
   
   // Print startup banner
   Print("========================================");
   Print("GoldPilotAI Enterprise v3.0 Started");
   Print("Symbol: ", Symbol());
   Print("Timeframe: ", Period());
   Print("Magic Number: ", MagicNumber);
   Print("Account: ", AccountNumber());
   Print("Initial Equity: $", DoubleToString(StartingEquity, 2));
   Print("========================================");
   
   return(INIT_SUCCEEDED);
}

//====================================================================
// MAIN TRADING LOGIC
//====================================================================
void OnTick()
{
   // Step 1: Update all indicators every tick
   UpdateIndicators();
   
   // Step 2: Check filters (early exit if conditions not met)
   if(!AllowTrading())
   {
      Print("BLOCKED -> AllowTrading()");
      UpdateChartComment();
      return;
   }
   
   // Step 3: Manage existing open positions
   ManageExits();
   
   Print("===== Step 4 =====");

   // Step 4: Generate trading signal
   SignalOutput signal = GenerateFinalSignal();
   
   Print("====================================");
   Print("Signal     = ", signal.Signal);
   Print("IsValid    = ", signal.IsValid);
   Print("Confidence = ", signal.Confidence);
   Print("Source     = ", signal.Source);
   Print("====================================");
   
   Print("===== Step 5 =====");

   // Step 5: Check if signal is valid and tradeable
   if(!IsSignalValid(signal))
   {
      Print("BLOCKED -> IsSignalValid()");
      Print("Signal=",signal.Signal);
      Print("Confidence=",signal.Confidence);
      Print("Source=",signal.Source);
      UpdateChartComment();
      return;
   }
   Print("===== Step 6 =====");
   // Step 6: Check money management limits
   if(!IsTradeAllowedByMoneyManagement())
   {
      Print("BLOCKED -> MoneyManagement");
      return;
   }

   Print("===== Step 7 =====");   
   // Step 7: Calculate Stop Loss
   double stopLoss;
   if(signal.Signal == SIGNAL_BUY)
   {
      stopLoss = CalculateSLBuy(ML_SL_Lookback);
   }
   else if(signal.Signal == SIGNAL_SELL)
   {
      stopLoss = CalculateSLSell(ML_SL_Lookback);
   }
   else
   {
      return;
   }
   
   // Step 8: Calculate risk and position size
   double slDistance = MathAbs((signal.Signal == SIGNAL_BUY ? Ask : Bid) - stopLoss) / Point;
   
   Print("===== Step 8 =====");
   // Use confidence-based position sizing
   double baseLot;
   if(UseConfidenceSizing)
   {
      double confidenceLot = GetLotSizeRiskBased(RiskPerTradePercent, slDistance);

      Print("Confidence Lot = ", DoubleToString(confidenceLot, 4));

      baseLot = ScaleLotByConfidence(confidenceLot, signal.Confidence);

      Print("Final Base Lot = ", DoubleToString(baseLot, 4));
   }
   else
   {
      Print("===== ELSE BEFORE GetLotSizeRiskBased =====");
      Print("RiskPerTradePercent = ", RiskPerTradePercent);
      Print("SL Distance = ", slDistance);
      baseLot = GetLotSizeRiskBased(RiskPerTradePercent, slDistance);
      Print("BASE LOT = ", DoubleToString(baseLot, 4));
   }
   
   Print("===== Step 9 =====");

   // Step 9: Calculate Take Profit
   double takeProfit;
   if(signal.Signal == SIGNAL_BUY)
   {
      takeProfit = Ask + (TakeProfitPoints * Point);
   }
   else
   {
      takeProfit = Bid - (TakeProfitPoints * Point);
   }
   
   Print("===== Step 10 =====");

   // Step 10: Validate trade risk
   TradeRisk tradeRisk = ValidateTradeRisk(
      (signal.Signal == SIGNAL_BUY ? Ask : Bid), 
      stopLoss, 
      takeProfit, 
      baseLot);
   
   if(!tradeRisk.IsValid)
   {
      Print("BLOCKED -> TradeRisk");
      Print(tradeRisk.ValidationError);
      LogWarning("Trade validation failed: " + tradeRisk.ValidationError, "OnTick");
      UpdateChartComment();
      return;
   }
   
   Print("D_===== Step 11 =====");

   // Step 11: Execute pre-trade risk check
   if(!PreTradeRiskCheck(tradeRisk))
   {
      Print("D_BLOCKED -> PreTradeRiskCheck()");
      LogWarning("Risk check failed", "OnTick");
      UpdateChartComment();
      return;
   }
   
   Print("D_==============================");
   Print("D_READY TO PLACE TRADE");
   Print("D_Signal=",signal.Signal);
   Print("D_Lot=",baseLot);
   Print("D_SL=",stopLoss);
   Print("D_TP=",takeProfit);
   Print("D_==============================");

   Print("D_===== Step 12 =====");

   // Step 12: Place trade
   int ticket = 0;
   if(signal.Signal == SIGNAL_BUY)
   {
      if(CountOpenBuyOrders() > 0)
      {
         Print("BUY already open");
         return;
      }
      ticket = PlaceBuyOrder(Ask, stopLoss, takeProfit, baseLot, 
                            GetSignalComment(signal));
   }
   else if(signal.Signal == SIGNAL_SELL)
   {
      if(CountOpenSellOrders() > 0)
      {
         Print("Sell already open");
         return;
      }
      ticket = PlaceSellOrder(Bid, stopLoss, takeProfit, baseLot,
                             GetSignalComment(signal));
   }
   
   // Step 13: Log trade entry
   if(ticket > 0)
   {
      LogTradeEntry(ticket, signal.Signal, 
                   (signal.Signal == SIGNAL_BUY ? Ask : Bid),
                   stopLoss, takeProfit, baseLot, 
                   signal.Source, signal.Confidence);
      
      DrawEntryMarker((signal.Signal == SIGNAL_BUY ? Ask : Bid), 
                     signal.Signal == SIGNAL_BUY);
   }
   
   Print("===== Step 14 =====");

   // Step 14: Update dashboard
   UpdateDashboard(signal.Signal, signal.Confidence, signal.Source);
   
   // Step 15: Maintenance tasks
   MaintainLogger();
   CleanupOldMarkers();
}

//====================================================================
// DEINITIALIZATION
//====================================================================
void OnDeinit(const int reason)
{
   // Log shutdown with reason
   string reasonText = "";
   switch(reason)
   {
      case REASON_PROGRAM: reasonText = "Program removed"; break;
      case REASON_CHARTCHANGE: reasonText = "Chart changed"; break;
      case REASON_CHARTCLOSE: reasonText = "Chart closed"; break;
      case REASON_PARAMETERS: reasonText = "Parameters changed"; break;
      case REASON_ACCOUNT: reasonText = "Account changed"; break;
      case REASON_INITFAILED: reasonText = "Init failed"; break;
      case REASON_CLOSE: reasonText = "Terminal closed"; break;
      default: reasonText = "Unknown"; break;
   }
   
   LogEAShutdown(reasonText);
   
   // Log final statistics
   LogDailySummary();
   
   // Clean up dashboard
   CleanupDashboard();
   
   // Print shutdown banner
   Print("========================================");
   Print("GoldPilotAI Enterprise v3.0 Stopped");
   Print("Reason: ", reasonText);
   Print("Final Equity: $", DoubleToString(AccountEquity(), 2));
   Print("Total Trades Today: ", TodayTrades);
   Print("========================================");
}

//====================================================================
// END OF EA
//====================================================================