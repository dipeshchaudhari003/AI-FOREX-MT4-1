//+------------------------------------------------------------------+
//| Config.mqh                                                       |
//| GoldPilotAI Enterprise v3.0                                      |
//+------------------------------------------------------------------+
#ifndef __CONFIG_MQH__
#define __CONFIG_MQH__

//==============================
// GENERAL
//==============================
input double LotSize               = 0.01;
input int    MagicNumber           = 202501;


//==============================
// TP / SL
//==============================
input int DefaultTakeProfit        = 50;
input int DefaultStopLoss          = 100;
input int TakeProfitPoints         = 100;  // Alternative naming
input int StopLossPoints           = 50;   // Alternative naming

input int BreakEvenPoints          = 10;

//==============================
// STRUCTURE SL
//==============================
input int ML_SL_Lookback           = 10;
input int ML_MinSL_Points          = 120;
input int ML_MaxSL_Points          = 350;

//==============================
// MANUAL
//==============================
input int ManualSLLookback         = 8;
input int ManualMaxSL              = 400;
input int ManualBreakEven          = 15;

//==============================
// FILTERS
//==============================
input int ATRPeriod                = 14;
input int ATRMinimum               = 25;
input int ATRMaximum               = 180;

input int ADXPeriod                = 14;
input int ADXMinimum               = 22;

input int EMAFast                  = 20;
input int EMASlow                  = 50;
input int EMATrend                 = 200;

//==============================
// SESSION
//==============================
input int TradingStartHour         = 8;
input int TradingEndHour           = 21;

//==============================
// RISK
//==============================
input int MaxTradesPerDay          = 10;

//==============================
// TIMEFRAMES
//==============================
input ENUM_TIMEFRAMES EntryTF   = PERIOD_M1;   // Entry timeframe
input ENUM_TIMEFRAMES TrendTF   = PERIOD_M5;   // Trend filter
input ENUM_TIMEFRAMES ConfirmTF = PERIOD_M15;  // Higher timeframe confirmation

//==============================
// FILTERS
//==============================
input double MaxSpreadPoints = 150;
input double MinATRPoints = 80;
input double MinADX = 20;

//==============================
// Session
//==============================
input int LondonOpenHour = 8;
input int NewYorkCloseHour = 22;


//==============================
// Risk
//==============================

input int MaxConsecutiveLosses = 3;
input double MinConfidence      = 0.60;

//==============================
// ENTRY LOGIC PARAMETERS
//==============================

// RSI Filter
input int RSIPeriod             = 14;
input int RSIOverbought         = 70;
input int RSIOversold           = 30;

// Stochastic Filter
input int StochPeriod           = 14;
input int StochOverbought       = 80;
input int StochOversold         = 20;

// Bollinger Bands
input int BollingerPeriod       = 20;
input int BollingerDeviation    = 2;

// Candle Filter
input int MinCandleBodyPoints   = 5;

// Trading Timing
input int CooldownSeconds       = 5;

// Confidence Requirement
input double MinConfidenceRequired = 0.60;

// Debug Flags
input bool DebugEntryLogic      = false;

//==============================
// EXIT LOGIC PARAMETERS
//==============================

// Trailing Stop
input bool UseTrailingStop      = true;
input int TrailingStopPoints    = 30;

// Dynamic Take Profit (ATR-based)
input bool UseDynamicTP         = true;
input double ATRTPFactor        = 2.0;  // ATR * 2.0 = TP distance
input int ATRTPMaximum          = 200;  // Maximum TP in points

//==============================
// TRADE MANAGER PARAMETERS
//==============================

// Order Placement Constraints
input int MaxSlippage           = 3;    // Maximum slippage in pips
input double MinimumLotSize     = 0.01; // Minimum lot size
input double MaximumLotSize     = 1.0;  // Maximum lot size

// SL/TP Distances
input int MinimumSLDistance     = 50;   // Minimum SL distance in points
input int MinimumTPDistance     = 50;   // Minimum TP distance in points
input double RiskRewardRatio    = 1.5;  // Minimum R:R ratio (0 = disabled)

// SL Buffer
input int SLBuffer              = 2;    // Buffer between SL and lowest/highest

//==============================
// MONEY MANAGEMENT PARAMETERS
//==============================

// Risk Per Trade
input double RiskPerTradePercent = 2.0;  // Risk 2% of equity per trade

// Daily Limits
input double MaxDailyLossPercent = 5.0;  // Stop trading after 5% loss
input double MaxDailyWinPercent  = 10.0; // Take profit after 10% gain
input double MaxDrawdownLimit    = 15.0; // Maximum drawdown tolerance

// Position Sizing
input bool UseFixedLotSize       = true;  // Use LotSize parameter
input bool UseRiskBasedSizing    = false; // Calculate size based on risk%

//==============================
// RISK MANAGER PARAMETERS
//==============================

// Risk Per Trade
input double MaxRiskPercent      = 2.5;  // Max risk % per single trade
input double MaxRiskPerTrade     = 100;  // Max risk in dollars per trade

// Risk/Reward Requirements
input double MinRRRatio          = 1.5;  // Minimum risk/reward ratio (1.5:1)

// Debug Flags
input bool DebugRiskManager      = false;

//==============================
// ML PREDICTOR PARAMETERS
//==============================

// ML Integration
input bool UseMLSignals          = true;   // Enable ML signal integration
input bool RequireMLConfirmation = false;  // Require ML to confirm technical

// Debug Flags
input bool DebugMLPredictor      = false;

//==============================
// CONFIDENCE SCORE PARAMETERS
//==============================

// Confidence Weighting
input double TechnicalWeight     = 0.60; // Technical 60% of confidence
input double MLWeight            = 0.40; // ML 40% of confidence

// Confidence-Based Sizing
input bool UseConfidenceSizing   = true; // Scale position by confidence
input bool UseConfidenceTiers    = false; // Use tier-based sizing

// Debug Flags
input bool DebugConfidenceScore  = false;

//==============================
// SIGNAL ENGINE PARAMETERS
//==============================

// Strategy Mode
input int SignalStrategy         = 1;    // 0=Conservative, 1=Balanced, 2=Aggressive

#define STRATEGY_CONSERVATIVE    0
#define STRATEGY_BALANCED        1
#define STRATEGY_AGGRESSIVE      2

// Confidence Thresholds by Mode
input double ConservativeConfidenceThreshold = 0.80;  // Both must agree + high confidence
input double BalancedConfidenceThreshold     = 0.65;  // Moderate agreement + confidence
input double AggressiveConfidenceThreshold   = 0.50;  // Either strong signal alone

// Debug Flags
input bool DebugSignalEngine     = false;

//==============================
// LOGGER PARAMETERS
//==============================

// Logging Control
input bool EnableLogging         = true;   // Enable all logging
input bool PrintToJournal        = true;   // Print to MT4 journal
input int LogLevelFilter         = 1;      // 0=Debug, 1=Info, 2=Warning, 3=Error, 4=Critical

// Log Rotation
input bool EnableLogRotation     = true;   // Enable automatic log rotation
input int LogMaxSizeKB           = 500;    // Max log file size in KB before rotation

// Debug
input bool DebugLogger           = false;

//==============================
// STATISTICS PARAMETERS
//==============================

// Statistics Logging
input bool EnableStatisticsLogging = true;  // Enable statistics calculations
input bool TrackStrategyPerformance = true; // Track by signal source
input bool CalculateAdvancedMetrics = true; // Calculate Sharpe, Sortino, Recovery

// Debug
input bool DebugStatistics       = false;

//==============================
// DASHBOARD PARAMETERS
//==============================

// Dashboard Display
input bool EnableDashboard       = true;   // Enable chart dashboard
input bool ShowEntryMarkers      = true;   // Show entry arrows
input bool ShowExitMarkers       = true;   // Show exit markers
input int MaxHistoryBars         = 500;    // Keep markers for N bars

// Chart Display
input bool UseChartComment       = true;   // Use chart comment display
input bool UseTextObjects        = true;   // Use text object display

// Debug
input bool DebugDashboard        = false;

#endif