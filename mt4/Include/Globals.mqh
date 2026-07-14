//+------------------------------------------------------------------+
//| Globals.mqh                                                      |
//| GoldPilotAI Enterprise v3.0                                      |
//+------------------------------------------------------------------+
#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__

//=====================================================
// TIME
//=====================================================

datetime lastTradeTime      = 0;
datetime lastCloseTime      = 0;
datetime lastBarTime        = 0;
datetime lastLogTime        = 0;

//=====================================================
// TRADE
//=====================================================

int LastSignal             = 0;
int LastDirection          = 0;
int ConsecutiveLosses      = 0;
int TodayTrades            = 0;
int WinningTrades          = 0;
int LosingTrades           = 0;

bool AllowTrade            = true;

//=====================================================
// PRICE
//=====================================================

double CurrOpen            = 0;
double CurrHigh            = 0;
double CurrLow             = 0;
double CurrClose           = 0;

double PrevOpen            = 0;
double PrevHigh            = 0;
double PrevLow             = 0;
double PrevClose           = 0;

//=====================================================
// EMA
//=====================================================

double EMA9               = 0;
double EMA20              = 0;
double EMA21              = 0;
double EMA50              = 0;
double EMA200             = 0;

double EMA20_M15          = 0;
double EMA50_M15          = 0;

//=====================================================
// VOLATILITY
//=====================================================

double ATR                = 0;
double ADX                = 0;
double Spread             = 0;

//=====================================================
// BOLLINGER
//=====================================================

double BBUpper            = 0;
double BBMiddle           = 0;
double BBLower            = 0;

//=====================================================
// STOCHASTIC
//=====================================================

double StochMain          = 0;
double StochSignal        = 0;

//=====================================================
// RSI
//=====================================================

double RSI                = 0;

//=====================================================
// CANDLE
//=====================================================

double CandleBody         = 0;
double CandleRange        = 0;
double UpperWick          = 0;
double LowerWick          = 0;

//=====================================================
// ML
//=====================================================

double ConfidenceScore    = 0;
double BuyProbability     = 0;
double SellProbability    = 0;

//=====================================================
// SESSION
//=====================================================

bool LondonSession        = false;
bool NewYorkSession       = false;
bool AsianSession         = false;

//=====================================================
// FILTERS
//=====================================================

bool TrendOK              = false;
bool SpreadOK             = false;
bool ATR_OK               = false;
bool ADX_OK               = false;
bool SessionOK            = false;
bool ConfidenceOK         = false;

//=====================================================
// DEBUG
//=====================================================

string DebugMessage       = "";

#endif